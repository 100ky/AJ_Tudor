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
