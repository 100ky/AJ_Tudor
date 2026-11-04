import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/audio/audio_playback_service.dart';
import 'package:aj_tudor/services/gemini/gemini_live_client.dart';

void main() {
  late GeminiLiveClient client;

  setUp(() {
    client = GeminiLiveClient('test-key', AudioPlaybackService());
  });

  test('the end of a turn already sees the token usage sent with it', () {
    // Agent podle spotřeby při turnComplete rozhoduje o obnově spojení. Dřív viděl
    // spotřebu z předchozí zprávy, a tak spojení obnovil podruhé hned po prvním tahu.
    int? tokensAtTurnEnd;
    client.onTurnComplete = () => tokensAtTurnEnd = client.currentTokenCount;

    client.handleMessageForTesting(jsonEncode({
      'serverContent': {'turnComplete': true},
      'usageMetadata': {'totalTokenCount': 7968},
    }));

    expect(tokensAtTurnEnd, 7968);
  });

  group('speech confirmed by the server', () {
    late List<String> sent;

    setUp(() {
      sent = [];
      client.attachSinkForTesting(sent.add);
    });

    /// Druhy odeslaných zpráv realtimeInput (activityStart, audio, activityEnd).
    List<String> sentKinds() => [
          for (final message in sent)
            ((jsonDecode(message) as Map)['realtimeInput'] as Map).keys.single as String,
        ];

    void server(String type) => client.handleMessageForTesting(jsonEncode({
          'voiceActivity': {'type': type},
        }));

    /// Krátká replika („Mhm“) odeslaná celá najednou.
    void shortReply() {
      client.sendActivityStart();
      server('ACTIVITY_START');
      client.sendAudioChunk([1, 2]);
      client.sendActivityEnd();
    }

    test('the next speech waits until the server confirms the end of the previous one', () {
      // Lekce 19: student mluvil dál 0,5 s po krátkém „Mhm“. Server activityStart poslaný
      // před potvrzením konce zahodil i se zvukem a na další řeč už neodpověděl.
      shortReply();
      client.sendActivityStart();
      client.sendAudioChunk([3, 4]);
      expect(sentKinds(), ['activityStart', 'audio', 'activityEnd']);

      server('ACTIVITY_END');
      expect(sentKinds(), ['activityStart', 'audio', 'activityEnd', 'activityStart', 'audio']);

      // Další zvuk už jde rovnou
      client.sendAudioChunk([5, 6]);
      expect(sentKinds().last, 'audio');
      expect(sent, hasLength(6));
    });

    test('a speech already ended while waiting is sent whole and waits for its own confirmation', () {
      shortReply();
      client.sendActivityStart();
      client.sendAudioChunk([3, 4]);
      client.sendActivityEnd();
      client.sendActivityStart();

      server('ACTIVITY_END');
      // Třetí řeč čeká na potvrzení konce druhé
      expect(sentKinds(), ['activityStart', 'audio', 'activityEnd', 'activityStart', 'audio', 'activityEnd']);

      server('ACTIVITY_END');
      expect(sentKinds().last, 'activityStart');
    });

    test('without the server confirming speech the next speech is not delayed', () {
      client.sendActivityStart();
      client.sendActivityEnd();
      client.sendActivityStart();
      expect(sentKinds(), ['activityStart', 'activityEnd', 'activityStart']);
    });

    testWidgets('an end the server never confirms is reported and the held speech is sent', (tester) async {
      var unconfirmed = 0;
      client.onActivityEndUnconfirmed = () => unconfirmed++;
      shortReply();
      client.sendActivityStart();

      await tester.pump(const Duration(milliseconds: 2900));
      expect(unconfirmed, 0);
      expect(sentKinds(), ['activityStart', 'audio', 'activityEnd']);

      await tester.pump(const Duration(milliseconds: 200));
      expect(unconfirmed, 1);
      expect(sentKinds().last, 'activityStart');
    });

    testWidgets('a confirmed end is not reported', (tester) async {
      var unconfirmed = 0;
      client.onActivityEndUnconfirmed = () => unconfirmed++;
      shortReply();
      server('ACTIVITY_END');

      await tester.pump(const Duration(seconds: 5));
      expect(unconfirmed, 0);
    });

    test('a new connection forgets the held speech', () {
      shortReply();
      client.sendActivityStart();
      client.sendAudioChunk([3, 4]);

      client.forceReconnect();
      client.attachSinkForTesting(sent.add);
      server('ACTIVITY_END');
      expect(sentKinds(), ['activityStart', 'audio', 'activityEnd']);
    });
  });

  test('a forced reconnect reports the drop and counts tokens from zero', () {
    final statuses = <bool>[];
    client.onConnectionStatusChanged = statuses.add;
    client.handleMessageForTesting(jsonEncode({
      'usageMetadata': {'totalTokenCount': 25701},
    }));
    expect(client.currentTokenCount, 25701);

    client.forceReconnect();

    // Agent se o výpadku dozví a po připojení obnoví kontext hovoru
    expect(statuses, [false]);
    expect(client.currentTokenCount, 0);
  });
}
