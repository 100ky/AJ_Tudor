import 'dart:typed_data';

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

/// Síťová vrstva, která nic neposílá: zapamatuje si požadavky a vrátí [body] jako JSON.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final String body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
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

  group('vyčerpaný denní limit (bezplatná úroveň)', () {
    // Tvar odpovědi Gemini API při vyčerpané kvótě (RESOURCE_EXHAUSTED s QuotaFailure)
    Map<String, Object> quota(String quotaId) => {
          'error': {
            'code': 429,
            'message': 'You exceeded your current quota, please check your plan and billing details.',
            'status': 'RESOURCE_EXHAUSTED',
            'details': [
              {
                '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                'violations': [
                  {'quotaId': quotaId}
                ],
              }
            ],
          }
        };
    final daily = _dioError(statusCode: 429, data: quota('GenerateRequestsPerDayPerProjectPerModel-FreeTier'));
    final perMinute = _dioError(statusCode: 429, data: quota('GenerateRequestsPerMinutePerProjectPerModel-FreeTier'));

    tearDown(() => ModelCooldownTracker().clear());

    test('denní limit se pozná podle quotaId, minutový a přetížení ne', () {
      expect(isDailyQuotaError(daily), isTrue);
      expect(isDailyQuotaError(perMinute), isFalse);
      expect(isDailyQuotaError(_dioError(statusCode: 503)), isFalse);
    });

    test('kvóta se obnovuje o půlnoci pacifického času (8:00 UTC)', () {
      expect(nextDailyQuotaReset(DateTime.utc(2026, 11, 6, 7, 30)), DateTime.utc(2026, 11, 6, 8));
      expect(nextDailyQuotaReset(DateTime.utc(2026, 11, 6, 15)), DateTime.utc(2026, 11, 7, 8));
    });

    test('model s vyčerpaným denním limitem se vynechá až do obnovy, minutový jen na minutu', () {
      final now = DateTime.utc(2026, 11, 6, 15);
      expect(cooldownAfter(daily, otherwise: const Duration(minutes: 3), now: now), const Duration(hours: 17));
      expect(cooldownAfter(perMinute, otherwise: const Duration(minutes: 3), now: now), const Duration(minutes: 1));
      expect(
        cooldownAfter(_dioError(statusCode: 503), otherwise: const Duration(minutes: 3), now: now),
        const Duration(minutes: 3),
      );
    });

    test('vyčerpaný denní limit platí pro všechny služby, přetížení jen pro tu jednu', () {
      // Dřív si ho každá služba zkoušela znovu po 2–3 minutách
      final transcription = ModelCooldownTracker();
      final translation = ModelCooldownTracker();
      transcription.markFailure('gemini-3.6-flash', daily, otherwise: const Duration(minutes: 2));
      expect(translation.order(['gemini-3.6-flash', 'gemini-3.5-flash-lite']), ['gemini-3.5-flash-lite']);

      transcription.markFailure('gemini-3.5-flash-lite', _dioError(statusCode: 503), otherwise: const Duration(minutes: 2));
      expect(translation.order(['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite']),
          ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite']);
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

  group('GeminiRestCore request', () {
    test('the API key travels in a header, never in the URL', () async {
      final adapter = _RecordingAdapter('{"candidates": []}');
      final api = GeminiRestCore(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
        httpClientAdapter: adapter,
      );

      await api.generateContent(apiKey: 'secret-key', model: 'gemini-test', body: const {'contents': []});

      final request = adapter.requests.single;
      // Adresu Dart vypisuje do textu výjimek, a ty končí v logu
      expect(request.uri.toString(), '${GeminiRestCore.baseUrl}/gemini-test:generateContent');
      expect(request.uri.toString(), isNot(contains('secret-key')));
      expect(request.headers['x-goog-api-key'], 'secret-key');
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
