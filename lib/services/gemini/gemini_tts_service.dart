import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }

  /// Aktuálně preferovaný funkční model.
  static String? get preferredWorkingModel => _preferredWorkingModel;

  /// Počet položek v audio mezipaměti.
  static int get cachedAudioCount => _audioCache.length;

  /// Vygeneruje a přehraje výslovnost zadaného textu.
  /// 
  /// [text] je anglický text k vyslovení.
  /// [instruction] volitelná instrukce pro intonaci či přízvuk (např. 'Speak slowly and emphasize past tense.').
  Future<bool> speak(String text, {String? instruction}) async {
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      L.w('Gemini TTS: Chybí API klíč, nelze přehrát výslovnost.');
      return false;
    }

    final voiceName = _ref.read(voiceProvider);
    final audioPlayback = _ref.read(audioPlaybackServiceProvider);

    final cleanText = sanitizeTextForSpeech(text);
    if (cleanText.isEmpty) return false;

    // 1. Zkontrolujeme paměťovou mezipaměť – pokud už máme audio vygenerované, přehrajeme ho ihned
    final cacheKey = '$cleanText-$voiceName';
    if (_audioCache.containsKey(cacheKey)) {
      final cachedBytes = _audioCache[cacheKey]!;
      L.i('Gemini TTS: Přehrávám z mezipaměti pro "$cleanText" (${cachedBytes.length} B).');
      await audioPlayback.playPcmData(cachedBytes);
      return true;
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

                    // Uložíme do mezipaměti (max 100 záznamů)
                    _audioCache[cacheKey] = bytes;
                    if (_audioCache.length > 100) {
                      _audioCache.remove(_audioCache.keys.first);
                    }

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
