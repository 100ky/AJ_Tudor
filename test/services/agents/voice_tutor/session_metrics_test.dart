import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/session_metrics.dart';

void main() {
  late DateTime now;
  late SessionMetrics metrics;

  void advance(int milliseconds) => now = now.add(Duration(milliseconds: milliseconds));

  setUp(() {
    now = DateTime(2026, 11, 11, 17, 48);
    metrics = SessionMetrics(now: () => now)..start();
  });

  group('reply latency of the tutor', () {
    test('is measured from the end of the student speech to the first reply', () {
      // Lekce 27: aplikace zapisovala 0–2 ms, tutor ve skutečnosti odpovídal za 0,8–2,7 s
      metrics.markUserSpeechEnd();
      expect(metrics.isAwaitingResponse, isTrue);
      advance(1420);
      metrics.recordResponseStart();

      expect(metrics.responseLatenciesMs, [1420]);
      expect(metrics.isAwaitingResponse, isFalse);
    });

    test('later parts of the same reply are not counted again', () {
      metrics.markUserSpeechEnd();
      advance(900);
      metrics.recordResponseStart();
      advance(200);
      metrics.recordResponseStart();

      expect(metrics.responseLatenciesMs, [900]);
    });

    test('a reply the student did not ask for (the opening line) has no latency', () {
      metrics.recordResponseStart();
      expect(metrics.responseLatenciesMs, isEmpty);
      expect(metrics.medianResponseLatencyMs, isNull);
    });

    test('the summary uses the median, one slow reply does not skew it', () {
      for (final latency in [990, 820, 9400]) {
        metrics.markUserSpeechEnd();
        advance(latency);
        metrics.recordResponseStart();
      }
      expect(metrics.medianResponseLatencyMs, 990);
    });
  });

  test('student replies are counted as they were saved to the transcript', () {
    // Souhrn lekcí 17–27 hlásil „user: 0“
    metrics.recordUserReply('Today I tried to make.');
    metrics.recordUserReply('I came up with a scenario');
    expect(metrics.userReplies, 2);
  });

  test('a new lesson starts from zero', () {
    metrics.recordUserReply('Hello');
    metrics.markUserSpeechEnd();
    advance(500);
    metrics.recordResponseStart();

    metrics.start();

    expect(metrics.userReplies, 0);
    expect(metrics.responseLatenciesMs, isEmpty);
    expect(metrics.isAwaitingResponse, isFalse);
  });
}
