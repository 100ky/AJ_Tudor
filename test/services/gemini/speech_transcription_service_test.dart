import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/services/gemini/gemini_rest_core.dart';
import 'package:aj_tudor/services/gemini/speech_transcription_service.dart';

class _MockRestCore extends Mock implements GeminiRestCore {}

class _FakeApiKeyNotifier extends ApiKeyNotifier {
  final String? key;
  _FakeApiKeyNotifier(this.key);

  @override
  String? build() => key;
}

Map<String, dynamic> _answer(String text) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    };

DioException _httpError(int statusCode) => DioException(
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: statusCode),
      type: DioExceptionType.badResponse,
    );

void main() {
  late _MockRestCore api;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    SpeechTranscriptionService.resetState();
    api = _MockRestCore();
  });

  SpeechTranscriptionService serviceWithKey(String? key) {
    final container = ProviderContainer(
      overrides: [
        apiKeyProvider.overrideWith(() => _FakeApiKeyNotifier(key)),
        speechTranscriptionServiceProvider
            .overrideWith((ref) => SpeechTranscriptionService(ref, api: api)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(speechTranscriptionServiceProvider);
  }

  void answerWith(Map<String, dynamic> Function() answer) {
    when(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => answer());
  }

  Map<String, dynamic> sentBody() => verify(() => api.generateContent(
        apiKey: any(named: 'apiKey'),
        model: any(named: 'model'),
        body: captureAny(named: 'body'),
      )).captured.single as Map<String, dynamic>;

  test('sends the audio as WAV with the tutor line and returns the cleaned transcript', () async {
    answerWith(() => _answer('**Cože?** To nevím.</code>'));
    final service = serviceWithKey('key');

    final text = await service.transcribe([1, 0, 2, 0], previousTutorLine: 'How does the manager use it?');

    expect(text, 'Cože? To nevím.');
    final body = sentBody();
    final parts = body['contents'][0]['parts'] as List;
    expect(parts[0]['inlineData']['mimeType'], 'audio/wav');
    expect(ascii.decode(base64Decode(parts[0]['inlineData']['data'] as String).sublist(0, 4)), 'RIFF');
    expect(parts[1]['text'], contains('How does the manager use it?'));
    expect(body['systemInstruction']['parts'][0]['text'], contains('česky'));
  });

  test('a two-word transcript of a long recording asks the next model', () async {
    // Lekce 25: flash-lite přepsal 13 s řeči jako „Hm,“
    final answers = [_answer('Hm,'), _answer('I work with AI. The AI explain me this hard loss.')];
    when(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => answers.removeAt(0));
    final longAudio = List<int>.filled(13 * 32000, 0);

    expect(await serviceWithKey('key').transcribe(longAudio), 'I work with AI. The AI explain me this hard loss.');
    // Krátká nahrávka s krátkým přepisem je v pořádku, i zopakovaná dvě slova ze 4 s
    answerWith(() => _answer('Yes.'));
    expect(await serviceWithKey('key').transcribe([1, 0, 2, 0]), 'Yes.');
    answerWith(() => _answer('their parents'));
    expect(await serviceWithKey('key').transcribe(List<int>.filled(4 * 32000, 0)), 'their parents');
  });

  test('a short transcript of a long recording stays when no model does better', () async {
    answerWith(() => _answer('Hm,'));
    expect(await serviceWithKey('key').transcribe(List<int>.filled(8 * 32000, 0)), 'Hm,');
  });

  test('a silence mark before speech is dropped', () async {
    answerWith(() => _answer('(ticho) Nevím, jaký solution jiný.'));
    expect(await serviceWithKey('key').transcribe([1, 0]), 'Nevím, jaký solution jiný.');
  });

  test('a recording without speech gives an empty transcript', () async {
    answerWith(() => _answer('(ticho)'));

    expect(await serviceWithKey('key').transcribe([1, 0]), '');
  });

  test('without an API key nothing is sent', () async {
    expect(await serviceWithKey(null).transcribe([1, 0]), isNull);
    verifyNever(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        ));
  });

  test('flash-lite goes first, 3.6 Flash with only 20 requests a day is the last resort', () {
    expect(SpeechTranscriptionService.models.first, GeminiModels.flashLite3_5);
    expect(SpeechTranscriptionService.models.last, GeminiModels.flash3_6);
  });

  test('a short reply fits only a few words, a made-up sentence does not', () {
    // 9. 11.: 240 ms hlasu ženy telefonující vedle a věta podle otázky tutora
    expect(SpeechTranscriptionService.fitsVoicedTime('Eh, so, they were changing at the same time?', 240), isFalse);
    expect(SpeechTranscriptionService.fitsVoicedTime('Yes, I do.', 240), isTrue);
    expect(SpeechTranscriptionService.fitsVoicedTime('I think so, yes.', 300), isTrue);
    expect(SpeechTranscriptionService.fitsVoicedTime('No, I have never been there.', 650), isTrue);
  });

  test('overloaded models fall back to the next one, a rejected key stops at once', () async {
    when(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).thenThrow(_httpError(503));
    expect(await serviceWithKey('key').transcribe([1, 0]), isNull);
    verify(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).called(greaterThan(1));

    SpeechTranscriptionService.resetState();
    when(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).thenThrow(_httpError(401));
    expect(await serviceWithKey('key').transcribe([1, 0]), isNull);
    verify(() => api.generateContent(
          apiKey: any(named: 'apiKey'),
          model: any(named: 'model'),
          body: any(named: 'body'),
        )).called(1);
  });
}
