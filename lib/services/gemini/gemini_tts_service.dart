import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../providers/audio_provider.dart';
import '../../providers/config_provider.dart';

/// Služba pro převod textu na řeč (Text-to-Speech) pomocí modelu Gemini TTS.
/// 
/// Umožňuje přehrát vzorovou britskou/americkou výslovnost libovolného slovíčka,
/// fráze nebo věty v chatu a na kartičkách (Flashcards).
class GeminiTtsService {
  final Ref _ref;
  final Dio _dio;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Paměťová mezipaměť vygenerovaných audio bytů pro okamžité opakované přehrávání bez sítě.
  static final Map<String, List<int>> _audioCache = {};

  /// Složka pro trvalou diskovou mezipaměť audia
  static Directory? _diskCacheDir;

  /// Složka pro trvalou diskovou mezipaměť audia (pro testy lze přepsat)
  static Directory? diskCacheDirOverride;

  /// Naposledy úspěšně použitý model pro okamžité generování dalších nahrávek.
  static String? _preferredWorkingModel;

  /// Dočasný cooldown pro přetížené/nedostupné modely.
  static final Map<String, DateTime> _modelCooldowns = {};

  /// Seznam podporovaných specializovaných TTS modelů v kaskádovém pořadí.
  static const List<String> _ttsModels = [
    GeminiModels.tts,          // gemini-3.1-flash-tts-preview
    GeminiModels.ttsFlash2_5,  // gemini-2.5-flash-tts
    GeminiModels.ttsPro2_5,    // gemini-2.5-pro-preview-tts
  ];

  GeminiTtsService(this._ref)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 12),
        ));

  /// Resetuje cache a model cooldowny (pro testování a debug).
  static void resetState() {
    _preferredWorkingModel = null;
    _modelCooldowns.clear();
    _audioCache.clear();
    _diskCacheDir = null;
    diskCacheDirOverride = null;
  }

  /// Aktuálně preferovaný funkční model.
  static String? get preferredWorkingModel => _preferredWorkingModel;

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

      // Formátování promptu dle oficiální Gemini TTS specifikace,
      // aby model oddělil instrukce od mluveného textu a nečetl pokyny nahlas.
      final String promptText;
      if (instruction != null && instruction.isNotEmpty) {
        promptText = '''$instruction
Read ONLY the transcript below with natural native pronunciation. Do not read directions.

#### TRANSCRIPT
$cleanText''';
      } else {
        promptText = '''Read ONLY the transcript below with standard, clear native pronunciation. Do not read directions.

#### TRANSCRIPT
$cleanText''';
      }

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': promptText}
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

      final now = DateTime.now();

      // Pokud máme naposledy úspěšný model, zkusíme ho jako první
      final candidateOrder = <String>[];
      if (_preferredWorkingModel != null && _ttsModels.contains(_preferredWorkingModel)) {
        candidateOrder.add(_preferredWorkingModel!);
      }
      for (final m in _ttsModels) {
        if (!candidateOrder.contains(m)) {
          candidateOrder.add(m);
        }
      }

      // Vyfiltrujeme modely v aktivním cooldownu
      var modelsToTry = candidateOrder.where((m) {
        final cooldown = _modelCooldowns[m];
        return cooldown == null || now.isAfter(cooldown);
      }).toList();

      if (modelsToTry.isEmpty) {
        modelsToTry = candidateOrder;
      }

      for (var model in modelsToTry) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            data: requestBody,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode == 200 && response.data != null) {
            final candidates = response.data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                for (var part in parts) {
                  final inlineData = part['inlineData'];
                  if (inlineData != null && inlineData['data'] != null) {
                    final String base64Data = inlineData['data'];
                    final bytes = base64Decode(base64Data);

                    // Zapamatujeme si fungující model a zrušíme cooldown
                    _preferredWorkingModel = model;
                    _modelCooldowns.remove(model);

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
                  }
                }
              }
            }
          }
        } catch (e) {
          final errorDetail = (e is DioException && e.response?.data != null)
              ? '${e.message} -> ${e.response?.data}'
              : e.toString();
          L.w('Gemini TTS model $model selhal, zkouším další fallback: $errorDetail');

          if (e is DioException && e.response?.statusCode == 404) {
            _modelCooldowns[model] = now.add(const Duration(hours: 12));
          } else {
            _modelCooldowns[model] = now.add(const Duration(minutes: 3));
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
