import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:aj_tudor/services/audio/audio_playback_service.dart';
import 'package:aj_tudor/services/gemini/gemini_live_client.dart';
import 'package:aj_tudor/services/gemini/live_session_continuity.dart';

/// Odchozí strana spojení: pamatuje si, co klient poslal.
class _FakeSink extends Fake implements WebSocketSink {
  final List<String> sent = [];

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

/// Spojení se serverem bez sítě: test určuje, co server pošle a kdy spojení zavře.
class _FakeChannel extends Fake implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeSink _sink = _FakeSink();
  int? _closeCode;
  String? _closeReason;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  /// Nastavení spojení, které klient poslal jako první zprávu.
  Map<String, dynamic> get setup =>
      (jsonDecode(_sink.sent.first) as Map<String, dynamic>)['setup'] as Map<String, dynamic>;

  void serverSays(Map<String, dynamic> message) => _incoming.add(jsonEncode(message));

  /// Server (s kódem), nebo síť (bez kódu) zavře spojení.
  void serverCloses([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _incoming.close();
  }
}

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

  group('session continuity (trial)', () {
    late List<_FakeChannel> channels;

    setUp(() {
      channels = [];
      client = GeminiLiveClient('test-key', AudioPlaybackService(), connectChannel: (uri) {
        final channel = _FakeChannel();
        channels.add(channel);
        return channel;
      });
    });

    /// Zahájí lekci a počká, až odejde nastavení spojení.
    Future<void> startLesson(WidgetTester tester) async {
      client.connect(modelName: 'gemini-test-live', systemPrompt: 'You are a tutor.');
      await tester.pump();
    }

    /// Server potvrdí nastavení a pošle token, na který jde navázat.
    Future<void> confirmSetupWithToken(WidgetTester tester, _FakeChannel channel, String token) async {
      channel.serverSays({'setupComplete': {}});
      channel.serverSays({
        'sessionResumptionUpdate': {'newHandle': token, 'resumable': true}
      });
      await tester.pump();
    }

    testWidgets('without the switch the setup asks for nothing extra', (tester) async {
      await startLesson(tester);

      expect(channels.single.setup.keys, isNot(contains('sessionResumption')));
      expect(channels.single.setup.keys, isNot(contains('contextWindowCompression')));

      // Token, který server pošle sám od sebe, se nepoužije
      await confirmSetupWithToken(tester, channels.single, 'token-1');
      client.forceReconnect();
      await tester.pump();
      expect(channels.last.setup.keys, isNot(contains('sessionResumption')));
      expect(client.resumedSession, isFalse);
    });

    testWidgets('with the switch the setup asks for a token and for context compression', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);

      final setup = channels.single.setup;
      // Obě pole jsou přímo v setup, ne v generationConfig
      expect(setup['sessionResumption'], <String, dynamic>{});
      expect(setup['contextWindowCompression'], {
        'slidingWindow': {'targetTokens': LiveSessionContinuity.compressionTargetTokens},
        'triggerTokens': LiveSessionContinuity.compressionTriggerTokens,
      });
      expect((setup['generationConfig'] as Map).keys, isNot(contains('contextWindowCompression')));
      expect(client.resumedSession, isFalse);
    });

    testWidgets('a new connection resumes with the last token the server marked as resumable', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);
      await confirmSetupWithToken(tester, channels.single, 'token-1');
      // Model zrovna mluví: na tento okamžik navázat nejde, platí předchozí token
      channels.single.serverSays({
        'sessionResumptionUpdate': {'newHandle': '', 'resumable': false}
      });
      await tester.pump();

      client.forceReconnect();
      await tester.pump();

      expect(channels, hasLength(2));
      expect(channels.last.setup['sessionResumption'], {'handle': 'token-1'});
      expect(client.resumedSession, isTrue);
    });

    testWidgets('a network drop keeps the token for the next attempt', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);
      await confirmSetupWithToken(tester, channels.single, 'token-1');

      // Spojení spadlo bez kódu od serveru (síť)
      channels.single.serverCloses();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(channels, hasLength(2));
      expect(channels.last.setup['sessionResumption'], {'handle': 'token-1'});
    });

    testWidgets('forgetting the session makes the next connection start fresh', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);
      await confirmSetupWithToken(tester, channels.single, 'token-1');

      // Agent to volá, když model neodpovídá nebo je kontext moc velký
      client.forgetSession();
      client.forceReconnect();
      await tester.pump();

      expect(channels.last.setup['sessionResumption'], <String, dynamic>{});
      expect(client.resumedSession, isFalse);
    });

    testWidgets('a new lesson does not resume the previous one', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);
      await confirmSetupWithToken(tester, channels.single, 'token-1');
      client.disconnect();

      await startLesson(tester);

      expect(channels.last.setup['sessionResumption'], <String, dynamic>{});
    });

    testWidgets('a token the server refuses is dropped and the next attempt goes without it', (tester) async {
      // S dřívějším modelem končilo navázání tokenem smyčkou zavření 1007
      client.sessionContinuity = true;
      await startLesson(tester);
      await confirmSetupWithToken(tester, channels.single, 'token-1');
      client.forceReconnect();
      await tester.pump();
      expect(channels.last.setup['sessionResumption'], {'handle': 'token-1'});

      channels.last.serverCloses(1007, 'Invalid session handle');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(channels, hasLength(3));
      // Žádost o token i komprese zůstávají, jen se nenavazuje
      expect(channels.last.setup['sessionResumption'], <String, dynamic>{});
      expect(channels.last.setup.keys, contains('contextWindowCompression'));
      expect(client.resumedSession, isFalse);
    });

    testWidgets('a refused setup first drops the compression, then the token request', (tester) async {
      client.sessionContinuity = true;
      await startLesson(tester);

      channels.last.serverCloses(1007, 'Unknown name "contextWindowCompression"');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(channels, hasLength(2));
      expect(channels.last.setup['sessionResumption'], <String, dynamic>{});
      expect(channels.last.setup.keys, isNot(contains('contextWindowCompression')));

      channels.last.serverCloses(1007, 'Unknown name "sessionResumption"');
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      // Lekce běží dál jako bez souvislého hovoru
      expect(channels, hasLength(3));
      expect(channels.last.setup.keys, isNot(contains('sessionResumption')));
      expect(channels.last.setup.keys, isNot(contains('contextWindowCompression')));
    });

    testWidgets('an error message before the setup is confirmed does not end the lesson', (tester) async {
      final errors = <String>[];
      client.onError = errors.add;
      client.sessionContinuity = true;
      await startLesson(tester);

      channels.last.serverSays({
        'error': {'message': 'contextWindowCompression is not supported'}
      });
      await tester.pump();

      expect(errors, isEmpty);
      expect(channels, hasLength(2));
      expect(channels.last.setup.keys, isNot(contains('contextWindowCompression')));
    });

    testWidgets('the confirmed setup is announced', (tester) async {
      var announced = 0;
      client.onSetupComplete = () => announced++;
      await startLesson(tester);
      expect(client.isConnected, isFalse);

      channels.single.serverSays({'setupComplete': {}});
      await tester.pump();

      expect(announced, 1);
      expect(client.isConnected, isTrue);
    });

    tearDown(() => client.disconnect());
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
