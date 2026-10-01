import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/config/config_providers.dart';
import '../prompt/task_prompts.dart';
import 'gemini_json.dart';
import 'gemini_rest_core.dart';

/// Výsledek vyhodnocení výslovnosti konkrétního slova.
class WordPronunciationResult {
  final String expectedWord;
  final String recognizedWord;
  final bool isAccurate;
  final double confidence;
  final String? phoneticTip;

  const WordPronunciationResult({
    required this.expectedWord,
    required this.recognizedWord,
    required this.isAccurate,
    this.confidence = 1.0,
    this.phoneticTip,
  });
}

/// Celkový výsledek analýzy výslovnosti nahrávky studenta.
class PronunciationAnalysis {
  final String referenceText;
  final String transcribedText;
  final double overallScore; // 0.0 až 1.0
  final List<WordPronunciationResult> words;
  final String feedback;

  const PronunciationAnalysis({
    required this.referenceText,
    required this.transcribedText,
    required this.overallScore,
    required this.words,
    required this.feedback,
  });
}

/// Služba pro vyhodnocování kvality výslovnosti pomocí modelu Gemini Transcribe.
class PronunciationService {
  final Ref _ref;
  final GeminiRestCore _api;

  /// Cooldown přetížených modelů (503, 429, timeout), aby nezdržovaly další kartičky,
  /// a naposledy funkční model pro okamžité vyhodnocení dalších nahrávek.
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// [api] lze v testech nahradit vlastním REST jádrem.
  PronunciationService(this._ref, {GeminiRestCore? api})
      : _api = api ??
            GeminiRestCore(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 8),
            );

  /// Resetuje zapamatovaný model a cooldowny (užitečné např. pro testy).
  static void resetState() => _cooldowns.clear();

  /// Aktuálně preferovaný funkční model.
  static String? get preferredWorkingModel => _cooldowns.preferredModel;

  /// Převede surová PCM 16-bit Mono data na standardní WAV soubor s 44-bytovou hlavičkou.
  Uint8List pcm16ToWav(List<int> pcmBytes, {int sampleRate = 16000, int channels = 1}) {
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final subChunk2Size = pcmBytes.length;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);
    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    header.setUint16(22, channels, Endian.little); // NumChannels
    header.setUint32(24, sampleRate, Endian.little); // SampleRate
    header.setUint32(28, byteRate, Endian.little); // ByteRate
    header.setUint16(32, blockAlign, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample
    // data sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, subChunk2Size, Endian.little);

    final wavBytes = Uint8List(44 + subChunk2Size);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + subChunk2Size, pcmBytes);
    return wavBytes;
  }

  /// Vyhodnotí mluvenou odpověď studenta pro zadanou kartičku.
  Future<PronunciationAnalysis?> evaluateSpokenAnswer({
    required List<int> audioBytes,
    required String expectedEnglish,
    String? promptContext,
  }) async {
    return evaluatePronunciation(
      audioBytes: audioBytes,
      referenceText: expectedEnglish,
      instructionHint: promptContext != null
          ? TaskPrompts.spokenAnswerHint(
              promptContext: promptContext,
              expectedEnglish: expectedEnglish,
            )
          : null,
    );
  }

  /// Analyzuje nahrávku studenta a porovná ji se vzorovou větou.
  /// 
  /// [audioBytes] jsou audio byty (16kHz PCM nebo WAV).
  /// [referenceText] je vzorový text, který měl student říct.
  Future<PronunciationAnalysis?> evaluatePronunciation({
    required List<int> audioBytes,
    required String referenceText,
    String? instructionHint,
    String mimeType = 'audio/wav',
  }) async {
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      L.w('PronunciationService: Chybí API klíč.');
      return null;
    }

    try {
      // Pokud data nemají RIFF hlavičku, automaticky je zabalíme do WAV
      List<int> effectiveBytes = audioBytes;
      if (audioBytes.length > 4 &&
          !(audioBytes[0] == 0x52 &&
              audioBytes[1] == 0x49 &&
              audioBytes[2] == 0x46 &&
              audioBytes[3] == 0x46)) {
        effectiveBytes = pcm16ToWav(audioBytes, sampleRate: 16000, channels: 1);
      }

      final base64Audio = base64Encode(effectiveBytes);

      final systemPrompt = TaskPrompts.pronunciationSystem(
        referenceText: referenceText,
        instructionHint: instructionHint,
      );

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Audio,
                }
              },
              {'text': TaskPrompts.pronunciationRequest(referenceText)}
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      };

      // Modely Flash-Lite a Flash 3.5 jsou pro audio multimodalitu řádově nejrychlejší
      // a netrpí přetížením (503), které v současnosti postihuje těžší modely 3.8 a 3.7.
      const baseModels = [
        GeminiModels.flashLite3_5,
        GeminiModels.flash3_5,
        GeminiModels.flashLite3_1,
        GeminiModels.flash2_5,
        GeminiModels.flash3_8,
        GeminiModels.flash3_7,
        GeminiModels.flash3_6,
      ];

      // Naposledy úspěšný model nasadíme jako první pro bleskovou odezvu,
      // modely v cooldownu po chybě 503 / timeoutu přeskočíme
      for (final model in _cooldowns.order(baseModels, preferLastWorking: true)) {
        try {
          final data = await _api.generateContent(
            apiKey: apiKey,
            model: model,
            body: requestBody,
          );
          final text = GeminiRestCore.extractText(data);
          if (text == null) continue;

          final json = decodeModelJson(text);
          final List<WordPronunciationResult> wordList = [];

          if (json['words'] is List) {
            for (var w in json['words']) {
              if (w is Map) {
                wordList.add(WordPronunciationResult(
                  expectedWord: w['expectedWord']?.toString() ?? '',
                  recognizedWord: w['recognizedWord']?.toString() ?? '',
                  isAccurate: w['isAccurate'] == true,
                  confidence: double.tryParse(w['confidence']?.toString() ?? '1.0') ?? 1.0,
                  phoneticTip: w['phoneticTip']?.toString(),
                ));
              }
            }
          }

          // Úspěch: uložíme jako preferovaný model pro další dotazy
          _cooldowns.markSuccess(model, remember: true);
          L.i('PronunciationService: Výslovnost úspěšně analyzována modelem $model.');

          return PronunciationAnalysis(
            referenceText: referenceText,
            transcribedText: json['transcribedText']?.toString() ?? '',
            overallScore: double.tryParse(json['overallScore']?.toString() ?? '0.8') ?? 0.8,
            words: wordList,
            feedback: json['feedback']?.toString() ?? 'Skvělá práce!',
          );
        } on DioException catch (e) {
          final kind = classifyGeminiError(e);
          if (kind == GeminiErrorKind.auth) {
            // Neplatný klíč odmítnou všechny modely – další pokusy jen zdržují.
            L.w('PronunciationService: API klíč byl odmítnut (${e.response?.statusCode}), další modely nezkouším.');
            break;
          }
          if (kind == GeminiErrorKind.overloaded) {
            _cooldowns.markOverloaded(model, const Duration(minutes: 3));
            L.w('Model $model je přetížený (${e.response?.statusCode ?? 0} / ${e.type.name}). Dávám na 3min cooldown.');
          } else {
            L.w('Model $model selhal při analýze výslovnosti: $e');
          }
        } catch (e) {
          L.w('Model $model selhal při analýze výslovnosti: $e');
        }
      }

      return null;
    } catch (e, stack) {
      L.e('Chyba při vyhodnocování výslovnosti', e, stack);
      return null;
    }
  }
}

/// Globální Riverpod provider pro [PronunciationService].
final pronunciationServiceProvider = Provider<PronunciationService>((ref) {
  return PronunciationService(ref);
});

