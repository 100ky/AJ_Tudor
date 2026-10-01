import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../audio/audio_providers.dart';
import '../../core/config/config_providers.dart';
import '../prompt/task_prompts.dart';
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
    GeminiModels.tts,          // gemini-3.1-flash-tts-preview
    GeminiModels.ttsFlash2_5,  // gemini-2.5-flash-tts
    GeminiModels.ttsPro2_5,    // gemini-2.5-pro-preview-tts
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
  /// [instruction] volitelná instrukce pro intonaci či přízvuk (např. 'Speak slowly and emphasize past tense.').
  Future<bool> speak(String text, {String? instruction}) async {
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
    final diskBytes = await _readFromDiskCache(cacheKey);
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

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': TaskPrompts.ttsTranscript(cleanText, instruction: instruction)}
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
          final bytes = _extractAudio(data);
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
          final errorDetail = (e is DioException && e.response?.data != null)
              ? '${e.message} -> ${e.response?.data}'
              : e.toString();
          L.w('Gemini TTS model $model selhal, zkouším další fallback: $errorDetail');

          // Neexistující model (404) vyřadíme na delší dobu, ostatní chyby jen krátce
          final notFound = e is DioException &&
              classifyGeminiError(e) == GeminiErrorKind.notFound;
          _cooldowns.markOverloaded(
            model,
            notFound ? const Duration(hours: 12) : const Duration(minutes: 3),
          );
        }
      }

      L.e('Gemini TTS: Žádný model nevrátil platné audio.');
      return false;
    } catch (e, stack) {
      L.e('Gemini TTS: Neočekávaná chyba při syntéze řeči', e, stack);
      return false;
    }
  }

  /// Najde v odpovědi první část s audio daty (`inlineData`) a dekóduje je.
  static List<int>? _extractAudio(Map<String, dynamic>? data) {
    final parts = GeminiRestCore.firstCandidateParts(data);
    if (parts == null) return null;
    for (final part in parts) {
      final inlineData = part['inlineData'];
      if (inlineData != null && inlineData['data'] != null) {
        return base64Decode(inlineData['data'] as String);
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
