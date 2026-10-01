import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/gemini/gemini_json.dart';
import 'package:aj_tudor/services/gemini/gemini_rest_core.dart';

DioException _dioError({
  int? statusCode,
  DioExceptionType type = DioExceptionType.badResponse,
  Object? data,
}) {
  final options = RequestOptions(path: '/models/test:generateContent');
  return DioException(
    requestOptions: options,
    type: type,
    message: 'dio message',
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode, data: data),
  );
}

Map<String, dynamic> _textResponse(String text) => {
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

void main() {
  group('ModelCooldownTracker', () {
    late ModelCooldownTracker tracker;

    setUp(() => tracker = ModelCooldownTracker());

    test('keeps candidate order and removes duplicates', () {
      expect(tracker.order(['a', 'b', 'a', 'c']), ['a', 'b', 'c']);
    });

    test('skips models in cooldown', () {
      tracker.markOverloaded('a', const Duration(minutes: 3));
      expect(tracker.order(['a', 'b', 'c']), ['b', 'c']);
    });

    test('returns every model when all of them are in cooldown', () {
      tracker.markOverloaded('a', const Duration(minutes: 3));
      tracker.markOverloaded('b', const Duration(minutes: 3));
      expect(tracker.order(['a', 'b']), ['a', 'b']);
    });

    test('expired cooldown makes the model available again', () {
      tracker.markOverloaded('a', const Duration(seconds: -1));
      expect(tracker.order(['a', 'b']), ['a', 'b']);
    });

    test('markSuccess clears the cooldown', () {
      tracker.markOverloaded('a', const Duration(minutes: 3));
      tracker.markSuccess('a');
      expect(tracker.order(['a', 'b']), ['a', 'b']);
      expect(tracker.preferredModel, isNull);
    });

    test('remembered model goes first only with preferLastWorking', () {
      tracker.markSuccess('c', remember: true);
      expect(tracker.preferredModel, 'c');
      expect(tracker.order(['a', 'b', 'c']), ['a', 'b', 'c']);
      expect(tracker.order(['a', 'b', 'c'], preferLastWorking: true), ['c', 'a', 'b']);
    });

    test('remembered model outside the candidate list is ignored', () {
      tracker.markSuccess('x', remember: true);
      expect(tracker.order(['a', 'b'], preferLastWorking: true), ['a', 'b']);
    });

    test('clear resets cooldowns and the preferred model', () {
      tracker.markOverloaded('a', const Duration(minutes: 3));
      tracker.markSuccess('b', remember: true);
      tracker.clear();
      expect(tracker.preferredModel, isNull);
      expect(tracker.order(['a', 'b'], preferLastWorking: true), ['a', 'b']);
    });
  });

  group('classifyGeminiError', () {
    test('401 and 403 are auth errors', () {
      expect(classifyGeminiError(_dioError(statusCode: 401)), GeminiErrorKind.auth);
      expect(classifyGeminiError(_dioError(statusCode: 403)), GeminiErrorKind.auth);
    });

    test('404 means the model was not found', () {
      expect(classifyGeminiError(_dioError(statusCode: 404)), GeminiErrorKind.notFound);
    });

    test('429, 500, 503 and missing response are overload', () {
      for (final code in [429, 500, 503]) {
        expect(classifyGeminiError(_dioError(statusCode: code)), GeminiErrorKind.overloaded,
            reason: 'status $code');
      }
      expect(
        classifyGeminiError(_dioError(type: DioExceptionType.connectionError)),
        GeminiErrorKind.overloaded,
      );
    });

    test('timeouts are overload', () {
      expect(
        classifyGeminiError(_dioError(statusCode: 200, type: DioExceptionType.receiveTimeout)),
        GeminiErrorKind.overloaded,
      );
      expect(
        classifyGeminiError(_dioError(statusCode: 200, type: DioExceptionType.connectionTimeout)),
        GeminiErrorKind.overloaded,
      );
    });

    test('400 is another error', () {
      expect(classifyGeminiError(_dioError(statusCode: 400)), GeminiErrorKind.other);
    });
  });

  group('geminiErrorMessage', () {
    test('prefers error.message from the response body', () {
      final e = _dioError(statusCode: 400, data: {
        'error': {'message': 'API key not valid'}
      });
      expect(geminiErrorMessage(e), 'API key not valid');
    });

    test('falls back to the Dio message', () {
      expect(geminiErrorMessage(_dioError(statusCode: 500, data: 'oops')), 'dio message');
    });
  });

  group('GeminiRestCore response parsing', () {
    test('extractText returns the first text part', () {
      expect(GeminiRestCore.extractText(_textResponse('Ahoj')), 'Ahoj');
    });

    test('extractText returns null for empty or malformed responses', () {
      expect(GeminiRestCore.extractText(null), isNull);
      expect(GeminiRestCore.extractText({'candidates': []}), isNull);
      expect(GeminiRestCore.extractText(_textResponse('')), isNull);
      expect(
        GeminiRestCore.extractText({
          'candidates': [
            {'content': {'parts': []}}
          ]
        }),
        isNull,
      );
    });

    test('requireText explains what is missing', () {
      expect(GeminiRestCore.requireText(_textResponse('OK')), 'OK');
      expect(
        () => GeminiRestCore.requireText(null),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Prázdná odpověď'))),
      );
      expect(
        () => GeminiRestCore.requireText({'candidates': []}),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Žádní kandidáti'))),
      );
      expect(
        () => GeminiRestCore.requireText(_textResponse('')),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Prázdný text'))),
      );
    });

    test('firstCandidateParts exposes non-text parts (e.g. TTS audio)', () {
      final parts = GeminiRestCore.firstCandidateParts({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inlineData': {'mimeType': 'audio/pcm', 'data': 'AAAA'}
                }
              ]
            }
          }
        ]
      });
      expect(parts, hasLength(1));
      expect(parts!.first['inlineData']['data'], 'AAAA');
    });
  });

  group('decodeModelJson', () {
    test('decodes plain JSON', () {
      expect(decodeModelJson('{"a": 1}'), {'a': 1});
    });

    test('strips ```json fences', () {
      expect(decodeModelJson('```json\n{"target": "give up"}\n```'), {'target': 'give up'});
    });

    test('strips bare ``` fences around a list', () {
      expect(decodeModelJson('```\n[1, 2]\n```'), [1, 2]);
    });

    test('stripCodeFences trims whitespace around the fenced content', () {
      expect(stripCodeFences('```json\n  {}  \n```\n\n'), '{}');
    });

    test('invalid JSON still throws FormatException', () {
      expect(() => decodeModelJson('not json'), throwsFormatException);
    });
  });
}
