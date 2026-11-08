import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/config/config_providers.dart';
import '../audio/pcm_wav.dart' as wav;
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
  Uint8List pcm16ToWav(List<int> pcmBytes, {int sampleRate = 16000, int channels = 1}) =>
      wav.pcm16ToWav(pcmBytes, sampleRate: sampleRate, channels: channels);

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

      // Nejdřív flash-lite (500 požadavků denně), 3.6 a 3.8 Flash mají jen 20 denně
      const baseModels = [
        GeminiModels.flashLite3_5,
        GeminiModels.flashLite3_1,
        GeminiModels.flash3_6,
        GeminiModels.flash3_8,
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

          // Bez přepisu nebo skóre nejde o správnou odpověď (dřív chybějící skóre znamenalo 0,8)
          final transcribed = json['transcribedText']?.toString().trim() ?? '';
          final score = transcribed.isEmpty ? 0.0 : (double.tryParse(json['overallScore']?.toString() ?? '') ?? 0.0);
          return PronunciationAnalysis(
            referenceText: referenceText,
            transcribedText: transcribed,
            overallScore: score.clamp(0.0, 1.0),
            words: wordList,
            feedback: json['feedback']?.toString() ?? (transcribed.isEmpty ? 'V nahrávce není slyšet řeč.' : ''),
          );
        } on DioException catch (e) {
          final kind = classifyGeminiError(e);
          if (kind == GeminiErrorKind.auth) {
            // Neplatný klíč odmítnou všechny modely – další pokusy jen zdržují.
            L.w('PronunciationService: API klíč byl odmítnut (${e.response?.statusCode}), další modely nezkouším.');
            break;
          }
          if (kind == GeminiErrorKind.overloaded) {
            _cooldowns.markFailure(model, e, otherwise: const Duration(minutes: 3));
            L.w(isDailyQuotaError(e)
                ? 'Model $model vyčerpal denní limit, výslovnost ho do obnovy kvóty vynechá.'
                : 'Model $model je přetížený (${e.response?.statusCode ?? 0} / ${e.type.name}). Zkouším další.');
          } else if (kind == GeminiErrorKind.notFound) {
            // Model bez cooldownu by zůstal jediný „dostupný“, když jsou ostatní přetížené,
            // a další pokus by po jeho 404 hned skončil, místo aby zkusil ostatní znovu
            _cooldowns.markOverloaded(model, const Duration(hours: 12));
            L.w('Model $model neexistuje (404), dalších 12 h ho nezkouším.');
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

