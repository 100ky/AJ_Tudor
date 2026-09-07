import 'dart:convert';
import 'dart:typed_data';
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
  final Dio _dio;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Naposledy úspěšně použitý model pro okamžité vyhodnocení dalších nahrávek.
  static String? _preferredWorkingModel;

  /// Dočasný cooldown pro přetížené modely (503, 429, timeout), aby nezdržovaly další kartičky.
  static final Map<String, DateTime> _modelCooldowns = {};

  PronunciationService(this._ref)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 8),
        ));

  /// Resetuje zapamatovaný model a cooldowny (užitečné např. pro testy).
  static void resetState() {
    _preferredWorkingModel = null;
    _modelCooldowns.clear();
  }

  /// Aktuálně preferovaný funkční model.
  static String? get preferredWorkingModel => _preferredWorkingModel;

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
          ? 'Student odpovídá na kartičku se zadáním: "$promptContext". Cílová správná odpověď: "$expectedEnglish".'
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

      final systemPrompt = '''Jsi expert na fonetiku a výslovnost moderního anglického jazyka.
Tvým úkolem je detailně analyzovat mluvenou nahrávku studenta a porovnat ji se vzorovým anglickým textem.
${instructionHint ?? ''}
Vzorový anglický text: "$referenceText"

Vyhodnoť:
1. "transcribedText": Přesný přepis toho, co student v angličtině skutečně vyslovil.
2. "overallScore": Celkové skóre výslovnosti a srozumitelnosti od 0.0 do 1.0 (např. 0.92 pro 92 %).
3. "words": Seznam všech rozpoznaných slov s detailním hodnocením:
   - "expectedWord": odpovídající vzorové slovo
   - "recognizedWord": slovo jak ho student vyslovil
   - "isAccurate": true pokud bylo slovo vysloveno foneticky správně a srozumitelně; false pokud byla výslovnost nepřesná, zkomolená nebo chyběla správná hláska.
   - "confidence": číslo 0.0 až 1.0
   - "phoneticTip": krátký český tip pro zlepšení tohoto konkrétního slova (např. "Pozor na znělé /ð/", "Otevřené /æ/").
4. "feedback": Stručné, vstřícné české shrnutí výslovnosti (max 2 věty).

Vrať VÝHRADNĚ validní JSON bez jakéhokoliv markdown formátování dle schématu:
{
  "transcribedText": "I am twenty five years old",
  "overallScore": 0.92,
  "feedback": "Velmi pěkná výslovnost, dej si jen pozor na hlásku v...",
  "words": [
    {
      "expectedWord": "I",
      "recognizedWord": "I",
      "isAccurate": true,
      "confidence": 0.98,
      "phoneticTip": ""
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
                'text': 'Zhodnoť výslovnost anglické nahrávky oproti vzorovému textu: "$referenceText"'
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

      final now = DateTime.now();

      // Pokud máme naposledy úspěšný model, nasadíme ho jako první pro bleskovou odezvu
      final candidateOrder = <String>[];
      if (_preferredWorkingModel != null && baseModels.contains(_preferredWorkingModel)) {
        candidateOrder.add(_preferredWorkingModel!);
      }
      for (final m in baseModels) {
        if (!candidateOrder.contains(m)) {
          candidateOrder.add(m);
        }
      }

      // Filtrujeme modely, které jsou v dočasném cooldownu po chybě 503 / timeoutu
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
              final text = candidates[0]['content']?['parts']?[0]?['text']?.toString();
              if (text != null && text.isNotEmpty) {
                final cleanJson = text
                    .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
                    .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
                    .trim();

                final json = jsonDecode(cleanJson);
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
                _preferredWorkingModel = model;
                _modelCooldowns.remove(model);
                L.i('PronunciationService: Výslovnost úspěšně analyzována modelem $model.');

                return PronunciationAnalysis(
                  referenceText: referenceText,
                  transcribedText: json['transcribedText']?.toString() ?? '',
                  overallScore: double.tryParse(json['overallScore']?.toString() ?? '0.8') ?? 0.8,
                  words: wordList,
                  feedback: json['feedback']?.toString() ?? 'Skvělá práce!',
                );
              }
            }
          }
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode ?? 0;
          final isOverloaded = statusCode == 503 ||
              statusCode == 429 ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout;

          if (isOverloaded) {
            _modelCooldowns[model] = DateTime.now().add(const Duration(minutes: 3));
            L.w('Model $model je přetížený ($statusCode / ${e.type.name}). Dávám na 3min cooldown.');
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

