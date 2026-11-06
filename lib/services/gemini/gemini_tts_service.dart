import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../audio/audio_providers.dart';
import '../audio/pcm_wav.dart';
import '../../core/config/config_providers.dart';
import 'gemini_rest_core.dart';

/// Služba pro převod textu na řeč (Text-to-Speech) pomocí modelu Gemini TTS.
/// 
/// Umožňuje přehrát vzorovou britskou/americkou výslovnost libovolného slovíčka,
/// fráze nebo věty v chatu a na kartičkách (Flashcards).
class GeminiTtsService {
  final Ref _ref;
  final GeminiRestCore _api;

  /// Paměťová mezipaměť vygenerovaných audio bytů pro okamžité opakované přehrávání bez sítě.
  static final Map<String, List<int>> _audioCache = {};

  /// Složka pro trvalou diskovou mezipaměť audia
  static Directory? _diskCacheDir;

  /// Složka pro trvalou diskovou mezipaměť audia (pro testy lze přepsat)
  static Directory? diskCacheDirOverride;

  /// Cooldown přetížených/nedostupných modelů a naposledy funkční model
  /// pro okamžité generování dalších nahrávek.
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// Seznam podporovaných specializovaných TTS modelů v kaskádovém pořadí.
  static const List<String> _ttsModels = [
    GeminiModels.tts,      // gemini-3.8-flash-tts
    GeminiModels.ttsLite,  // gemini-3.8-flash-lite-tts
  ];

  GeminiTtsService(this._ref)
      : _api = GeminiRestCore(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 12),
        );

  /// Resetuje cache a model cooldowny (pro testování a debug).
  static void resetState() {
    _cooldowns.clear();
    _audioCache.clear();
    _diskCacheDir = null;
    diskCacheDirOverride = null;
  }

  /// Aktuálně preferovaný funkční model.
  static String? get preferredWorkingModel => _cooldowns.preferredModel;

  /// Počet položek v paměťové audio mezipaměti.
  static int get cachedAudioCount => _audioCache.length;

  /// Získá nebo vytvoří složku pro diskovou mezipaměť audia.
  static Future<Directory?> _getCacheDir() async {
    if (diskCacheDirOverride != null) return diskCacheDirOverride;
    if (_diskCacheDir != null) return _diskCacheDir;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'aj_tudor_tts_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _diskCacheDir = cacheDir;
      return cacheDir;
    } catch (e) {
      L.w('Gemini TTS: Nepodařilo se získat složku pro diskovou mezipaměť: $e');
      return null;
    }
  }

  /// Vygeneruje bezpečný a unikátní název souboru pro zadaný klíč mezipaměti.
  static String _generateCacheFileName(String cacheKey) {
    final sanitized = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final prefix = sanitized.length > 30 ? sanitized.substring(0, 30) : sanitized;
    final hash = cacheKey.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return '${prefix}_$hash.pcm';
  }

  /// Přečte nahrávku z trvalé diskové mezipaměti.
  static Future<List<int>?> _readFromDiskCache(String cacheKey) async {
    try {
      final dir = await _getCacheDir();
      if (dir == null) return null;
      final file = File(p.join(dir.path, _generateCacheFileName(cacheKey)));
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      L.w('Gemini TTS: Chyba při čtení z diskové mezipaměti: $e');
    }
    return null;
  }

  /// Uloží vygenerované audio byty do trvalé diskové mezipaměti.
  static Future<void> _writeToDiskCache(String cacheKey, List<int> bytes) async {
    try {
      final dir = await _getCacheDir();
      if (dir == null) return;
      final file = File(p.join(dir.path, _generateCacheFileName(cacheKey)));
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      L.w('Gemini TTS: Chyba při zápisu do diskové mezipaměti: $e');
    }
  }

  /// Smaže jednu nahrávku z trvalé diskové mezipaměti.
  static Future<void> _deleteFromDiskCache(String cacheKey) async {
    try {
      final dir = await _getCacheDir();
      if (dir == null) return;
      final file = File(p.join(dir.path, _generateCacheFileName(cacheKey)));
      if (await file.exists()) await file.delete();
    } catch (e) {
      L.w('Gemini TTS: Chyba při mazání z diskové mezipaměti: $e');
    }
  }

  /// Smaže celou diskovou mezipaměť vygenerovaných nahrávek.
  static Future<void> clearDiskCache() async {
    try {
      final dir = await _getCacheDir();
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _diskCacheDir = null;
    } catch (e) {
      L.w('Gemini TTS: Chyba při mazání diskové mezipaměti: $e');
    }
  }

  /// Vygeneruje a přehraje výslovnost zadaného textu.
  ///
  /// [text] je anglický text k vyslovení.
  Future<bool> speak(String text) async {
    final cleanText = sanitizeTextForSpeech(text);
    if (cleanText.isEmpty) return false;

    final voiceName = _ref.read(voiceProvider);
    final audioPlayback = _ref.read(audioPlaybackServiceProvider);

    // 1. Zkontrolujeme paměťovou mezipaměť – pokud už máme audio vygenerované, přehrajeme ho ihned
    final cacheKey = '$cleanText-$voiceName';
    if (_audioCache.containsKey(cacheKey)) {
      final cachedBytes = _audioCache[cacheKey]!;
      L.i('Gemini TTS: Přehrávám z paměťové mezipaměti pro "$cleanText" (${cachedBytes.length} B).');
      await audioPlayback.playPcmData(cachedBytes);
      return true;
    }

    // 2. Zkontrolujeme trvalou diskovou mezipaměť
    var diskBytes = await _readFromDiskCache(cacheKey);
    if (diskBytes != null && isWav(diskBytes)) {
      // Celý WAV se do mezipaměti ukládal jen před opravou: gemini-3.8-flash-tts v něm
      // předčítal i pokyny („Read only the transcript below…“), nahrávka se vytvoří znovu
      L.i('Gemini TTS: Nahrávka "$cleanText" v mezipaměti je ze starého pokynu, vytvořím ji znovu.');
      await _deleteFromDiskCache(cacheKey);
      diskBytes = null;
    }
    if (diskBytes != null && diskBytes.isNotEmpty) {
      L.i('Gemini TTS: Přehrávám z diskové mezipaměti pro "$cleanText" (${diskBytes.length} B).');
      _audioCache[cacheKey] = diskBytes;
      await audioPlayback.playPcmData(diskBytes);
      return true;
    }

    // 3. Pro generování nového audia přes síť potřebujeme platný API klíč
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      L.w('Gemini TTS: Chybí API klíč, nelze přehrát výslovnost.');
      return false;
    }

    try {
      L.i('Gemini TTS: Generuji výslovnost pro text: "$cleanText" (hlas: $voiceName)...');

      // Jen samotný text: gemini-3.8-flash-tts předčítal nahlas i pokyny kolem něj
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': cleanText}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceName,
              }
            }
          }
        }
      };

      // Naposledy úspěšný model zkusíme jako první, modely v cooldownu přeskočíme
      for (final model in _cooldowns.order(_ttsModels, preferLastWorking: true)) {
        try {
          final data = await _api.generateContent(
            apiKey: apiKey,
            model: model,
            body: requestBody,
          );
          final bytes = extractAudio(data);
          if (bytes == null) continue;

          // Zapamatujeme si fungující model a zrušíme cooldown
          _cooldowns.markSuccess(model, remember: true);

          // Uložíme do mezipaměti (max 100 záznamů v paměti)
          _audioCache[cacheKey] = bytes;
          if (_audioCache.length > 100) {
            _audioCache.remove(_audioCache.keys.first);
          }

          // Uložíme do trvalé diskové mezipaměti na pozadí
          unawaited(_writeToDiskCache(cacheKey, bytes));

          // Přehrání surových PCM/audio bytů
          await audioPlayback.playPcmData(bytes);
          L.i('Gemini TTS: Výslovnost úspěšně přehrána modelem $model (${bytes.length} B).');
          return true;
        } catch (e) {
          if (e is DioException) {
            final isNetworkError = e.error is SocketException || e.type == DioExceptionType.connectionError;
            if (isNetworkError) {
              L.w('Gemini TTS: Chyba sítě (bez internetu). Přehrávání se neuskuteční.');
              return false;
            }
          }

          final errorDetail = (e is DioException && e.response?.data != null)
              ? '${e.message} -> ${e.response?.data}'
              : e.toString();
          L.w('Gemini TTS model $model selhal, zkouším další fallback: $errorDetail');

          // Neexistující model (404) vyřadíme na delší dobu, ostatní chyby jen krátce
          final notFound = e is DioException &&
              classifyGeminiError(e) == GeminiErrorKind.notFound;
          if (notFound) {
            _cooldowns.markOverloaded(model, const Duration(hours: 12));
          } else if (e is DioException) {
            // gemini-3.8-flash-tts má na bezplatné úrovni jen 10 požadavků denně
            _cooldowns.markFailure(model, e, otherwise: const Duration(minutes: 3));
          } else {
            _cooldowns.markOverloaded(model, const Duration(minutes: 3));
          }
        }
      }

      L.e('Gemini TTS: Žádný model nevrátil platné audio.');
      return false;
    } catch (e, stack) {
      L.e('Gemini TTS: Neočekávaná chyba při syntéze řeči', e, stack);
      return false;
    }
  }

  /// Najde v odpovědi první část s audio daty (`inlineData`) a vrátí z ní surové PCM.
  ///
  /// Starší modely vrací rovnou PCM, gemini-3.8-flash-tts celý WAV soubor: jeho hlavička
  /// a metadata C2PA za zvukem by se přehrály jako šum, proto se z něj vezme jen zvuk.
  @visibleForTesting
  static List<int>? extractAudio(Map<String, dynamic>? data) {
    final parts = GeminiRestCore.firstCandidateParts(data);
    if (parts == null) return null;
    for (final part in parts) {
      final inlineData = part['inlineData'];
      if (inlineData != null && inlineData['data'] != null) {
        final bytes = base64Decode(inlineData['data'] as String);
        final wav = pcm16FromWav(bytes);
        if (wav == null) return bytes;
        if (wav.sampleRate != 24000) {
          L.w('Gemini TTS: Nahrávka má ${wav.sampleRate} Hz, přehrávání počítá s 24000 Hz.');
        }
        return wav.pcm;
      }
    }
    return null;
  }

  /// Zastaví aktuálně probíhající přehrávání výslovnosti.
  Future<void> stop() async {
    final audioPlayback = _ref.read(audioPlaybackServiceProvider);
    await audioPlayback.stop();
  }

  /// Očistí text od markdown značek (hvězdičky, mřížky, odrážky),
  /// aby syntetizér četl přirozeně a nevyslovoval formátovací značky.
  static String sanitizeTextForSpeech(String rawText) {
    return rawText
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'[#_~]'), '')
        .trim();
  }
}

/// Globální Riverpod provider pro [GeminiTtsService].
final geminiTtsServiceProvider = Provider<GeminiTtsService>((ref) {
  return GeminiTtsService(ref);
});
