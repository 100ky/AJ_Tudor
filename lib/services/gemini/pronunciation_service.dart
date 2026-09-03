import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../providers/config_provider.dart';

/// Výsledek vyhodnocení výslovnosti konkrétního slova.
class WordPronunciationResult {
  final String expectedWord;
  final String recognizedWord;
  final bool isAccurate;
  final double confidence;

  const WordPronunciationResult({
    required this.expectedWord,
    required this.recognizedWord,
    required this.isAccurate,
    this.confidence = 1.0,
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
  final Dio _dio;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  PronunciationService(this._ref)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Analyzuje nahrávku studenta a porovná ji se vzorovou větou.
  /// 
  /// [audioBytes] jsou surové audio byty (např. 16kHz nebo 24kHz PCM / WAV).
  /// [referenceText] je vzorový text, který měl student přečíst.
  Future<PronunciationAnalysis?> evaluatePronunciation({
    required List<int> audioBytes,
    required String referenceText,
    String mimeType = 'audio/pcm;rate=24000',
  }) async {
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      L.w('PronunciationService: Chybí API klíč.');
      return null;
    }

    try {
      final base64Audio = base64Encode(audioBytes);

      final systemPrompt = '''Jsi expert na fonetiku a výslovnost anglického jazyka.
Tvým úkolem je porovnat nahrávku studenta se vzorovým textem (reference text).
Vzorový text: "$referenceText"

Vyhodnoť:
1. Převedený text (přepis toho, co student skutečně řekl).
2. Celkové skóre výslovnosti a srozumitelnosti (0.0 až 1.0).
3. Analýzu po jednotlivých slovech (zda bylo slovo vysloveno srozumitelně a správně).
4. Krátkou českou zpětnou vazbu k výslovnosti (např. na které hlásky dát pozor: th, w/v, otevřené samohlásky).

Vrať VÝHRADNĚ validní JSON bez markdownu dle schématu:
{
  "transcribedText": "string",
  "overallScore": 0.9,
  "feedback": "string v češtině",
  "words": [
    {
      "expectedWord": "string",
      "recognizedWord": "string",
      "isAccurate": true,
      "confidence": 0.95
    }
  ]
}''';

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
              {
                'text': 'Zhodnoť výslovnost nahrávky oproti referenčnímu textu: "$referenceText"'
              }
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

      final modelsToTry = [
        GeminiModels.transcribe,
        GeminiModels.flash3_8,
        GeminiModels.flash3_7,
        GeminiModels.flash3_6,
      ];

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
              final text = candidates[0]['content']?['parts']?[0]?['text']?.toString();
              if (text != null && text.isNotEmpty) {
                final json = jsonDecode(text);
                final List<WordPronunciationResult> wordList = [];

                if (json['words'] is List) {
                  for (var w in json['words']) {
                    if (w is Map) {
                      wordList.add(WordPronunciationResult(
                        expectedWord: w['expectedWord']?.toString() ?? '',
                        recognizedWord: w['recognizedWord']?.toString() ?? '',
                        isAccurate: w['isAccurate'] == true,
                        confidence: double.tryParse(w['confidence']?.toString() ?? '1.0') ?? 1.0,
                      ));
                    }
                  }
                }

                return PronunciationAnalysis(
                  referenceText: referenceText,
                  transcribedText: json['transcribedText']?.toString() ?? '',
                  overallScore: double.tryParse(json['overallScore']?.toString() ?? '0.8') ?? 0.8,
                  words: wordList,
                  feedback: json['feedback']?.toString() ?? 'Dobrá práce!',
                );
              }
            }
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

