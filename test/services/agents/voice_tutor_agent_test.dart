import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_live_client.dart';
import 'package:aj_tudor/services/gemini/speech_transcription_service.dart';
import 'package:aj_tudor/services/prompt/live_tutor_prompts.dart';
import 'package:aj_tudor/services/audio/audio_session_controller.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/services/agents/memory_manager_agent.dart';
import 'package:aj_tudor/services/system/wakelock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aj_tudor/core/utils/result.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/services/agents/voice_director_agent.dart';

class MockGeminiLiveClient extends Mock implements GeminiLiveClient {}
class MockAudioSessionController extends Mock implements AudioSessionController {}
class MockSessionRepository extends Mock implements SessionRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockMemoryManagerAgent extends Mock implements MemoryManagerAgent {}
class MockWakelockService extends Mock implements WakelockService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockSpeechTranscriber extends Mock implements SpeechTranscriptionService {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Režisér, který neanalyzuje, jen si schová callbacky pro předání rady.
class _CapturingDirector extends VoiceDirectorAgent {
  final List<void Function(String whisper)> whisperCallbacks = [];

  @override
  Future<void> onTurnCompleted({
    required int sessionId,
    required List<ChatMessage> messages,
    required String targetLevel,
    required String? userFacts,
    required String? recentTopics,
    required void Function(String whisper) onWhisperReady,
  }) async {
    whisperCallbacks.add(onWhisperReady);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late ProviderContainer container;
  late List<Override> overrides;
  late MockGeminiLiveClient mockClient;
  late MockAudioSessionController mockAudio;
  late MockSessionRepository mockRepo;
  late MockProfileRepository mockProfileRepo;
  late MockMemoryManagerAgent mockMemory;
  late MockWakelockService mockWakelock;
  late MockSharedPreferences mockPrefs;
  late MockFlutterSecureStorage mockStorage;
  late MockSpeechTranscriber mockTranscriber;

  setUpAll(() {
    registerFallbackValue(DateTime(2000));
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    mockClient = MockGeminiLiveClient();
    mockAudio = MockAudioSessionController();
    mockRepo = MockSessionRepository();
    mockProfileRepo = MockProfileRepository();
    mockMemory = MockMemoryManagerAgent();
    mockWakelock = MockWakelockService();
    mockPrefs = MockSharedPreferences();
    mockStorage = MockFlutterSecureStorage();
    mockTranscriber = MockSpeechTranscriber();

    // Setup default responses for mocks
    when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockPrefs.getString(any())).thenReturn(null);
    when(() => mockPrefs.getBool(any())).thenReturn(false);
    
    // Async cleanup methods must return completed futures
    when(() => mockAudio.stop()).thenAnswer((_) async {});
    when(() => mockAudio.stopPlayback()).thenAnswer((_) async {});
    when(() => mockRepo.closeSession(any())).thenAnswer((_) async => Result.success(null));
    when(() => mockRepo.addTranscript(
      sessionId: any(named: 'sessionId'),
      speaker: any(named: 'speaker'),
      content: any(named: 'content'),
      timestamp: any(named: 'timestamp'),
    )).thenAnswer((_) async => Result.success(null));
    when(() => mockMemory.analyzeSession(any())).thenAnswer((_) async {});
    // Ruční detekce řeči a opravný přepis (bez API klíče přepis nevrátí nic)
    when(() => mockClient.sendActivityStart()).thenReturn(true);
    when(() => mockClient.sendActivityEnd()).thenReturn(true);
    when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
        .thenAnswer((_) async => null);
    // disconnect might be called
    when(() => mockClient.disconnect()).thenAnswer((_) {});
    when(() => mockClient.isConnected).thenReturn(true);

    overrides = [
        geminiLiveClientProvider.overrideWithValue(mockClient),
        audioSessionControllerProvider.overrideWithValue(mockAudio),
        sessionRepositoryProvider.overrideWithValue(mockRepo),
        profileRepositoryProvider.overrideWithValue(mockProfileRepo),
        memoryManagerAgentProvider.overrideWithValue(mockMemory),
        wakelockServiceProvider.overrideWithValue(mockWakelock),
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        secureStorageProvider.overrideWithValue(mockStorage),
        speechTranscriptionServiceProvider.overrideWithValue(mockTranscriber),
      ];
    container = ProviderContainer(overrides: overrides);
  });

  tearDown(() {
    try {
      container.dispose();
    } catch (_) {}
  });

  test('Initial state is idle', () {
    final state = container.read(voiceTutorAgentProvider);
    expect(state.status, TutorState.idle);
    expect(state.messages, isEmpty);
  });

  test('selectScenario updates state', () {
    final agent = container.read(voiceTutorAgentProvider.notifier);
    agent.selectScenario(1, 'Test context');
    
    final state = container.read(voiceTutorAgentProvider);
    expect(state.selectedScenarioId, 1);
    expect(state.scenarioContext, 'Test context');
  });

  test('selectScenario can select and then clear scenario and free talk', () {
    final agent = container.read(voiceTutorAgentProvider.notifier);
    
    // 1. Zvolíme volný režim
    agent.selectScenario(-1, '__free_talk__');
    var state = container.read(voiceTutorAgentProvider);
    expect(state.selectedScenarioId, -1);
    expect(state.scenarioContext, '__free_talk__');

    // 2. Vynulujeme scénář
    agent.selectScenario(0, '');
    state = container.read(voiceTutorAgentProvider);
    expect(state.selectedScenarioId, isNull);
    expect(state.scenarioContext, isNull);

    // 3. Zvolíme konkrétní scénář
    agent.selectScenario(42, 'Roleplay at hotel');
    state = container.read(voiceTutorAgentProvider);
    expect(state.selectedScenarioId, 42);
    expect(state.scenarioContext, 'Roleplay at hotel');

    // 4. Opět vynulujeme
    agent.selectScenario(0, '');
    state = container.read(voiceTutorAgentProvider);
    expect(state.selectedScenarioId, isNull);
    expect(state.scenarioContext, isNull);
  });

  test('onUserTranscriptReceived correctly concatenates sub-word tokens', () async {
    Function(String)? userTranscriptCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockRepo.addTranscript(
      sessionId: any(named: 'sessionId'),
      speaker: any(named: 'speaker'),
      content: any(named: 'content'),
    )).thenAnswer((_) async {
      return Result.success(null);
    });
    final startExpectation = when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk')));
    startExpectation.thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {
      return;
    });

    // Intercept setter for onUserTranscriptReceived
    when(() => mockClient.onUserTranscriptReceived = any()).thenAnswer((invocation) => 
        userTranscriptCallback = invocation.positionalArguments[0] as Function(String)?);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(userTranscriptCallback, isNotNull);

    // Simulate Gemini sending sub-word tokens: " Hi", "s", " fa", "vorite"
    userTranscriptCallback!(' Hi');
    userTranscriptCallback!('s');
    userTranscriptCallback!(' fa');
    userTranscriptCallback!('vorite');

    final state = container.read(voiceTutorAgentProvider);
    expect(state.messages.length, 1);
    expect(state.messages.first.text, 'His favorite');
  });

  test('reconnection restores context and returns to listening state', () async {
    Function(bool)? connectionStatusCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendClientContent(
      role: any(named: 'role'),
      text: any(named: 'text'),
      turnComplete: any(named: 'turnComplete'),
    )).thenAnswer((_) {});

    when(() => mockClient.onConnectionStatusChanged = any()).thenAnswer((invocation) => 
        connectionStatusCallback = invocation.positionalArguments[0] as Function(bool)?);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(connectionStatusCallback, isNotNull);

    // Simulate disconnect during active session
    connectionStatusCallback!(false);
    expect(container.read(voiceTutorAgentProvider).status, TutorState.reconnecting);

    // Simulate successful reconnect
    connectionStatusCallback!(true);
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);
  });

  test('forceTopicChange immediately prompts model with turnComplete: true and enters thinking state', () async {
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendClientContent(
      role: any(named: 'role'),
      text: any(named: 'text'),
      turnComplete: any(named: 'turnComplete'),
    )).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);

    agent.forceTopicChange();

    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);
    verify(() => mockAudio.stopPlayback()).called(1);
    verify(() => mockClient.sendClientContent(
      role: 'user',
      text: any(named: 'text', that: contains('CRITICAL INSTRUCTION')),
      turnComplete: true,
    )).called(1);
  });

  test('quiet guidance waits for the tutor to finish its turn so it does not cut the tutor off', () async {
    void Function()? turnCompleteCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockAudio.isPlaying).thenReturn(false);
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.currentTokenCount).thenReturn(0);
    when(() => mockClient.sendClientContent(
      role: any(named: 'role'),
      text: any(named: 'text'),
      turnComplete: any(named: 'turnComplete'),
    )).thenAnswer((_) {});
    when(() => mockClient.onTurnComplete = any()).thenAnswer((invocation) =>
        turnCompleteCallback = invocation.positionalArguments[0] as void Function()?);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    // Rada režiséra dorazí, zatímco tutor mluví – zpráva clientContent by ho utnula
    agent.injectMidSessionGuidance('[DIRECTOR WHISPER] Ask about the garden.');
    verifyNever(() => mockClient.sendClientContent(
      role: any(named: 'role'),
      text: any(named: 'text'),
      turnComplete: any(named: 'turnComplete'),
    ));

    // Tutor domluvil – teprve teď se rada odešle
    expect(turnCompleteCallback, isNotNull);
    turnCompleteCallback!();
    verify(() => mockClient.sendClientContent(
      role: 'user',
      text: any(named: 'text', that: contains('Ask about the garden.')),
      turnComplete: false,
    )).called(1);

    // Fronta je prázdná, další konec tahu už nic neposílá
    turnCompleteCallback!();
    verifyNever(() => mockClient.sendClientContent(
      role: any(named: 'role'),
      text: any(named: 'text'),
      turnComplete: any(named: 'turnComplete'),
    ));
  });

  test('interruptPlayback stops audio playback and returns state to listening', () async {
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockAudio.isPlaying).thenReturn(true);
    when(() => mockAudio.stopPlayback()).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});

    Function(String)? textCallback;
    when(() => mockClient.onTextReceived = any()).thenAnswer((invocation) =>
        textCallback = invocation.positionalArguments[0] as Function(String)?);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    // Tutor starts speaking
    expect(textCallback, isNotNull);
    textCallback!('Hello there student, let me tell you...');
    expect(container.read(voiceTutorAgentProvider).status, TutorState.speaking);

    // Student interrupts tutor
    agent.interruptPlayback();

    verify(() => mockAudio.stopPlayback()).called(1);
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);
    expect(container.read(voiceTutorAgentProvider).messages.last.text, 'Hello there student, let me tell you...');
    expect(container.read(voiceTutorAgentProvider).messages.last.isUser, false);
  });

  test('startSession connects the live client once', () async {
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    verify(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).called(1);
  });

  test('long user speech: receiving multiple STT chunks does not end the speech or force a reconnect', () async {
    Function(String)? userTranscriptCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.forceReconnect()).thenAnswer((_) {});

    when(() => mockClient.onUserTranscriptReceived = any()).thenAnswer((invocation) => 
        userTranscriptCallback = invocation.positionalArguments[0] as Function(String)?);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(userTranscriptCallback, isNotNull);

    // Simulate long continuous monologue stream over time
    userTranscriptCallback!(' When I was younger');
    userTranscriptCallback!(', I used to live in a small town');
    userTranscriptCallback!(' where everybody knew each other');
    userTranscriptCallback!(' and we played outside until dark.');

    final state = container.read(voiceTutorAgentProvider);
    expect(state.status, TutorState.listening);
    expect(state.messages.length, 1);
    expect(state.messages.first.text, 'When I was younger, I used to live in a small town where everybody knew each other and we played outside until dark.');

    // Crucially: the speech must not be ended nor the connection reset while transcripts arrive!
    verifyNever(() => mockClient.sendActivityEnd());
    verifyNever(() => mockClient.forceReconnect());
  });

  test('continuous speech in thinking state reverts to listening and opens the speech', () async {
    Function(List<int>)? audioChunkCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.isPlaying).thenReturn(false);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((invocation) async {
      audioChunkCallback = invocation.namedArguments[const Symbol('onAudioChunk')] as Function(List<int>)?;
    });
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendAudioChunk(any())).thenAnswer((_) {});
    when(() => mockClient.sendText(any())).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(audioChunkCallback, isNotNull);

    // Manually put into thinking state (as if waiting for tutor response)
    agent.sendText('Thinking test');
    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);

    // User speaks again (100 ms blocks of audible 16-bit PCM) – 600 ms do not interrupt the tutor yet
    final audioBuffer = List<int>.filled(3200, 50);
    for (var i = 0; i < 6; i++) {
      audioChunkCallback!(audioBuffer);
    }
    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);
    verifyNever(() => mockClient.sendAudioChunk(any()));

    audioChunkCallback!(audioBuffer);

    // After 700 ms the state reverts to listening, the speech opens and all blocks reach the server
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);
    verify(() => mockClient.sendActivityStart()).called(1);
    verify(() => mockClient.sendAudioChunk(audioBuffer)).called(7);
  });

  test('ambient room noise does not trigger false speech detection or cancel silence timer', () async {
    Function(List<int>)? audioChunkCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.isPlaying).thenReturn(false);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((invocation) async {
      audioChunkCallback = invocation.namedArguments[const Symbol('onAudioChunk')] as Function(List<int>)?;
    });
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendAudioChunk(any())).thenAnswer((_) {});
    when(() => mockClient.sendText(any())).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(audioChunkCallback, isNotNull);

    // 1. Send 10 chunks of ambient room noise (RMS ~80, volume ~0.049, typical OnePlus noise floor)
    // 16-bit PCM little endian: byte[0]=80, byte[1]=0 -> sample = 80.
    final noiseChunk = List<int>.generate(640, (i) => i.isEven ? 80 : 0);
    for (int i = 0; i < 10; i++) {
      audioChunkCallback!(noiseChunk);
    }

    // Agent must stay in listening state without phantom speech detection
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);
    verifyNever(() => mockClient.sendActivityStart());

    // 2. Put into thinking state - ambient noise must NOT revert thinking to listening
    agent.sendText('Thinking test');
    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);

    for (int i = 0; i < 5; i++) {
      audioChunkCallback!(noiseChunk);
    }
    // Must remain in thinking state despite background noise
    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);
    // ...and without speech no audio reaches the server at all
    verifyNever(() => mockClient.sendAudioChunk(noiseChunk));
  });

  group('tutor turns', () {
    void Function()? turnCompleteCallback;
    Function(String)? textCallback;

    setUp(() {
      turnCompleteCallback = null;
      textCallback = null;
      when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
      when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
      when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
      when(() => mockAudio.isPlaying).thenReturn(false);
      when(() => mockClient.connect(
        modelName: any(named: 'modelName'),
        systemPrompt: any(named: 'systemPrompt'),
        voiceName: any(named: 'voiceName'),
        )).thenAnswer((_) {});
      when(() => mockClient.currentTokenCount).thenReturn(0);
      when(() => mockClient.onTurnComplete = any()).thenAnswer((invocation) => turnCompleteCallback =
          (invocation.positionalArguments[0] as void Function()?) ?? turnCompleteCallback);
      when(() => mockClient.onTextReceived = any()).thenAnswer((invocation) => textCallback =
          (invocation.positionalArguments[0] as Function(String)?) ?? textCallback);
    });

    test('a finished tutor turn does not cancel the pause set by the student', () async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      textCallback!('Tell me more about the app.');
      await agent.pauseSession();
      expect(container.read(voiceTutorAgentProvider).status, TutorState.paused);

      turnCompleteCallback!();

      final state = container.read(voiceTutorAgentProvider);
      expect(state.status, TutorState.paused);
      expect(state.messages.last.text, 'Tell me more about the app.');
    });

    test('a turn transcribed only as "..." is not added to the conversation', () async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      textCallback!('...');
      turnCompleteCallback!();

      final state = container.read(voiceTutorAgentProvider);
      expect(state.messages, isEmpty);
      expect(state.currentTranscript, isEmpty);
      verifyNever(() => mockRepo.addTranscript(
        sessionId: any(named: 'sessionId'),
        speaker: 'tutor',
        content: any(named: 'content'),
      ));
    });
  });

  test('stop while the session is being created in DB cancels the start and closes the new session', () async {
    final sessionCreated = Completer<Result<int>>();
    when(() => mockRepo.startNewSession()).thenAnswer((_) => sessionCreated.future);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    final start = agent.startSession();

    await agent.stopSession('test');
    sessionCreated.complete(Result.success(123));
    await start;

    expect(container.read(voiceTutorAgentProvider).status, TutorState.idle);
    verify(() => mockRepo.closeSession(123)).called(1);
    verifyNever(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    ));
  });

  test('stop while the profile is loading does not leave a call running without a DB session', () async {
    final profileLoaded = Completer<UserProfile?>();
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) => profileLoaded.future);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    final start = agent.startSession();
    await Future<void>.delayed(Duration.zero);

    await agent.stopSession('test');
    profileLoaded.complete(null);
    await start;

    expect(container.read(voiceTutorAgentProvider).status, TutorState.idle);
    verify(() => mockRepo.closeSession(123)).called(1);
    verify(() => mockMemory.analyzeSession(123)).called(1);
    verifyNever(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    ));
  });

  test('connection error closes the session and starts the analysis, error stays visible', () async {
    Function(String)? errorCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    // stopSession callbacky nuluje, proto si držíme ten poslední nenulový
    when(() => mockClient.onError = any()).thenAnswer((invocation) => errorCallback =
        (invocation.positionalArguments[0] as Function(String)?) ?? errorCallback);

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(errorCallback, isNotNull);
    errorCallback!('Nepodařilo se obnovit spojení po 5 pokusech.');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => mockRepo.closeSession(123)).called(1);
    verify(() => mockMemory.analyzeSession(123)).called(1);
    final state = container.read(voiceTutorAgentProvider);
    expect(state.status, TutorState.error);
    expect(state.errorMessage, 'Nepodařilo se obnovit spojení po 5 pokusech.');
  });

  test('start during an unfinished stop waits for it and keeps saving into the new session', () async {
    final audioStopped = Completer<void>();
    var audioStopCalls = 0;
    var nextSessionId = 123;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(nextSessionId++));
    when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockAudio.stop()).thenAnswer((_) => audioStopCalls++ == 0 ? audioStopped.future : Future.value());
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendText(any())).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    final stop = agent.stopSession('test');
    final restart = agent.startSession();
    audioStopped.complete();
    await stop;
    await restart;

    verify(() => mockRepo.closeSession(123)).called(1);
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);

    agent.sendText('Hello');
    verify(() => mockRepo.addTranscript(sessionId: 124, speaker: 'user', content: 'Hello')).called(1);
  });

  group('manual speech activity and corrected transcript', () {
    // Bloky po 100 ms (PCM 16-bit, 16 kHz): dva hlasité bloky jsou 200 ms řeči
    final loud = List<int>.filled(3200, 50);
    final quiet = List<int>.filled(3200, 0);
    final noise = List<int>.generate(640, (i) => i.isEven ? 80 : 0);

    late Function(List<int>) mic;
    Function(String)? userTranscript;
    Function(String)? tutorText;
    Function(bool)? connectionStatus;
    void Function()? turnComplete;
    void Function()? activityEndUnconfirmed;

    setUp(() {
      turnComplete = null;
      userTranscript = null;
      tutorText = null;
      connectionStatus = null;
      activityEndUnconfirmed = null;
      when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
      when(() => mockProfileRepo.getUserProfile()).thenAnswer((_) async => null);
      when(() => mockAudio.isPlaying).thenReturn(false);
      when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((invocation) async {
        mic = invocation.namedArguments[const Symbol('onAudioChunk')] as Function(List<int>);
      });
      when(() => mockClient.connect(
        modelName: any(named: 'modelName'),
        systemPrompt: any(named: 'systemPrompt'),
        voiceName: any(named: 'voiceName'),
      )).thenAnswer((_) {});
      when(() => mockClient.sendText(any())).thenAnswer((_) {});
      when(() => mockClient.forceReconnect()).thenAnswer((_) {});
      when(() => mockClient.currentTokenCount).thenReturn(0);
      // stopSession callbacky nuluje, proto si držíme ty poslední nenulové
      when(() => mockClient.onUserTranscriptReceived = any()).thenAnswer((invocation) => userTranscript =
          (invocation.positionalArguments[0] as Function(String)?) ?? userTranscript);
      when(() => mockClient.onTextReceived = any()).thenAnswer((invocation) =>
          tutorText = (invocation.positionalArguments[0] as Function(String)?) ?? tutorText);
      when(() => mockClient.onConnectionStatusChanged = any()).thenAnswer((invocation) => connectionStatus =
          (invocation.positionalArguments[0] as Function(bool)?) ?? connectionStatus);
      when(() => mockClient.onTurnComplete = any()).thenAnswer((invocation) => turnComplete =
          (invocation.positionalArguments[0] as void Function()?) ?? turnComplete);
      when(() => mockClient.onActivityEndUnconfirmed = any()).thenAnswer((invocation) =>
          activityEndUnconfirmed =
              (invocation.positionalArguments[0] as void Function()?) ?? activityEndUnconfirmed);
    });

    /// Student mluví [blocks] × 100 ms. Od 0,7 s je to jistě řeč a hned se posílá serveru.
    void speak([int blocks = 7]) {
      for (var i = 0; i < blocks; i++) {
        mic(loud);
      }
    }

    /// Student řekne větu a odmlčí se, takže se po tichu ohlásí konec řeči.
    Future<void> speakAndPause(WidgetTester tester) async {
      mic(noise);
      speak();
      mic(quiet);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
    }

    testWidgets('speech opens the activity with the pre-roll and silence ends it', (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      mic(noise);
      speak(6);
      // 0,6 s hlasu: replika se zatím jen nahrává
      verifyNever(() => mockClient.sendActivityStart());
      mic(loud);
      verifyInOrder([
        () => mockClient.sendActivityStart(),
        () => mockClient.sendAudioChunk(noise),
      ]);
      verify(() => mockClient.sendAudioChunk(loud)).called(7);

      mic(quiet);
      await tester.pump(const Duration(milliseconds: 1900));
      verifyNever(() => mockClient.sendActivityEnd());
      await tester.pump(const Duration(milliseconds: 200));
      verify(() => mockClient.sendActivityEnd()).called(1);
      expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);

      await agent.stopSession('test');
    });

    testWidgets('a short reply goes to Tudor only after the check finds speech', (tester) async {
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) async => 'Yes.');
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      speak(3); // „Yes.“: 0,3 s hlasu
      mic(quiet);
      verifyNever(() => mockClient.sendActivityStart());

      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      verifyInOrder([
        () => mockClient.sendActivityStart(),
        () => mockClient.sendAudioChunk(loud),
        () => mockClient.sendActivityEnd(),
      ]);
      expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);
      // Ověření poslouží jako opravný přepis, druhý požadavek se neposílá
      verify(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .called(1);

      await agent.stopSession('test');
    });

    testWidgets('a short sound without speech never reaches Tudor', (tester) async {
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) async => '');
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();
      await tester.pump(const Duration(seconds: 1)); // úvodní replika tutora
      clearInteractions(mockClient);

      speak(3); // „hm“, zakašlání nebo ruch
      mic(quiet);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();

      verifyNever(() => mockClient.sendActivityStart());
      verifyNever(() => mockClient.sendActivityEnd());
      verifyNever(() => mockClient.sendAudioChunk(any()));
      expect(container.read(voiceTutorAgentProvider).messages.where((m) => m.isUser), isEmpty);

      await agent.stopSession('test');
    });

    testWidgets('a sound at the very start does not swallow the tutor opening line', (tester) async {
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) async => '');
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      speak(3);
      mic(quiet);
      await tester.pump(const Duration(seconds: 1));
      // Replika se ještě ověřuje, úvod tutora čeká
      verifyNever(() => mockClient.sendText(any()));

      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      verify(() => mockClient.sendText(any())).called(1);

      await agent.stopSession('test');
    });

    testWidgets('a short sound does not open the speech', (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      // Klepnutí nebo nádech: 100 ms nad prahem řeči a zase ticho
      mic(loud);
      mic(quiet);
      mic(loud);
      mic(quiet);
      await tester.pump(const Duration(seconds: 3));

      verifyNever(() => mockClient.sendActivityStart());
      verifyNever(() => mockClient.sendAudioChunk(any()));

      await agent.stopSession('test');
    });

    testWidgets('a recording without speech removes the live "¿Qué?" and saves nothing', (tester) async {
      final correction = Completer<String?>();
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) => correction.future);
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      await speakAndPause(tester);
      userTranscript!('¿Qué?');
      expect(container.read(voiceTutorAgentProvider).messages.single.text, '¿Qué?');

      correction.complete(''); // opravný přepis: v nahrávce není řeč
      await tester.pump();
      tutorText!('Sorry, could you say that again?');
      await tester.pump();

      final messages = container.read(voiceTutorAgentProvider).messages;
      expect(messages.where((m) => m.isUser), isEmpty);
      verifyNever(() => mockRepo.addTranscript(
        sessionId: any(named: 'sessionId'),
        speaker: 'user',
        content: any(named: 'content'),
        timestamp: any(named: 'timestamp'),
      ));

      await agent.stopSession('test');
    });

    testWidgets('the configured patience decides how long the silence must be', (tester) async {
      when(() => mockPrefs.getInt(any())).thenReturn(800); // „Rychlá“ trpělivost
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      speak();
      mic(quiet);
      await tester.pump(const Duration(milliseconds: 1200));
      verifyNever(() => mockClient.sendActivityEnd());
      await tester.pump(const Duration(milliseconds: 200));
      verify(() => mockClient.sendActivityEnd()).called(1);

      await agent.stopSession('test');
    });

    testWidgets('a tutor turn ending while the student speaks does not keep the speech open', (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();
      speak();

      // Přerušená odpověď tutora skončí, zatímco student mluví
      turnComplete!();
      mic(quiet);
      await tester.pump(const Duration(milliseconds: 2100));
      verify(() => mockClient.sendActivityEnd()).called(1);

      await agent.stopSession('test');
    });

    testWidgets('pause keeps the student speech open and silence after resume ends it', (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();
      speak();
      verify(() => mockClient.sendActivityStart()).called(1);

      await agent.pauseSession();
      await tester.pump(const Duration(seconds: 5));
      verifyNever(() => mockClient.sendActivityEnd());

      await agent.resumeSession();
      mic(quiet);
      await tester.pump(const Duration(milliseconds: 2100));
      verify(() => mockClient.sendActivityEnd()).called(1);
      // Po obnovení pokračovala tatáž řeč
      verifyNever(() => mockClient.sendActivityStart());

      await agent.stopSession('test');
    });

    testWidgets('the corrected transcript replaces the live one in the bubble and in the lesson', (tester) async {
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) async => 'Cože? To nevím.');
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      await speakAndPause(tester);
      userTranscript!('¿Qué?');
      tutorText!('Let me explain.');
      await tester.pump();

      final messages = container.read(voiceTutorAgentProvider).messages;
      expect(messages.first.isUser, isTrue);
      expect(messages.first.text, 'Cože? To nevím.');
      verify(() => mockRepo.addTranscript(
        sessionId: 123,
        speaker: 'user',
        content: 'Cože? To nevím.',
        timestamp: any(named: 'timestamp'),
      )).called(1);
      verifyNever(() => mockRepo.addTranscript(
        sessionId: any(named: 'sessionId'),
        speaker: 'user',
        content: '¿Qué?',
        timestamp: any(named: 'timestamp'),
      ));

      await agent.stopSession('test');
    });

    testWidgets('without a corrected transcript the live one is saved', (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();

      await speakAndPause(tester);
      userTranscript!('I need practice.');
      tutorText!('Sure!');
      await tester.pump();

      verify(() => mockRepo.addTranscript(
        sessionId: 123,
        speaker: 'user',
        content: 'I need practice.',
        timestamp: any(named: 'timestamp'),
      )).called(1);

      await agent.stopSession('test');
    });

    testWidgets('ending the lesson waits for the corrected transcript before closing it', (tester) async {
      final correction = Completer<String?>();
      when(() => mockTranscriber.transcribe(any(), previousTutorLine: any(named: 'previousTutorLine')))
          .thenAnswer((_) => correction.future);
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();
      speak();

      final stop = agent.stopSession('test');
      await tester.pump();
      verifyNever(() => mockRepo.closeSession(any()));

      correction.complete('Only one manager has Power BI.');
      await tester.pump();
      await stop;
      // Úvodní replika tutora čeká 1 s po startu, ať po testu nezůstane časovač
      await tester.pump(const Duration(seconds: 1));

      verifyInOrder([
        () => mockRepo.addTranscript(
              sessionId: 123,
              speaker: 'user',
              content: 'Only one manager has Power BI.',
              timestamp: any(named: 'timestamp'),
            ),
        () => mockRepo.closeSession(123),
      ]);
    });

    testWidgets('a dropped connection ends the open speech locally and the next speech opens a new one',
        (tester) async {
      final agent = container.read(voiceTutorAgentProvider.notifier);
      await agent.startSession();
      speak();

      connectionStatus!(false);
      expect(container.read(voiceTutorAgentProvider).status, TutorState.reconnecting);
      verifyNever(() => mockClient.sendActivityEnd());

      connectionStatus!(true);
      mic(quiet);
      speak();
      verify(() => mockClient.sendActivityStart()).called(2);

      await agent.stopSession('test');
      await tester.pump(const Duration(seconds: 1));
    });

    group('waiting for the tutor reply', () {
      setUp(() {
        // Vynucený reconnect ohlásí výpadek jako skutečný klient
        when(() => mockClient.forceReconnect()).thenAnswer((_) => connectionStatus!(false));
      });

      testWidgets('without a reply the connection is restored 11 s after the end of speech', (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        await speakAndPause(tester);
        await tester.pump(const Duration(milliseconds: 10800));
        verifyNever(() => mockClient.forceReconnect());
        await tester.pump(const Duration(milliseconds: 200));
        verify(() => mockClient.forceReconnect()).called(1);
        expect(container.read(voiceTutorAgentProvider).status, TutorState.reconnecting);

        await agent.stopSession('test');
      });

      testWidgets('asking again does not restart the wait and the tutor answers the reply after the reconnect',
          (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        // Lekce 18: model na „čočková polévka“ neodpověděl a student se po 4 s ticha
        // ozval znovu („Haló?“). Každá replika dřív lhůtu vynulovala, takže nikdy nedoběhla.
        await speakAndPause(tester);
        userTranscript!('czeska polivka');
        for (var i = 0; i < 2; i++) {
          await tester.pump(const Duration(seconds: 4));
          await speakAndPause(tester);
        }

        // Od první repliky uběhlo přes 11 s, na poslední má model ještě 5 s
        await tester.pump(const Duration(milliseconds: 4700));
        verifyNever(() => mockClient.forceReconnect());
        await tester.pump(const Duration(milliseconds: 400));
        verify(() => mockClient.forceReconnect()).called(1);
        expect(container.read(voiceTutorAgentProvider).status, TutorState.reconnecting);

        // Nové spojení dostane kontext a tutor hned odpoví na nezodpovězenou repliku
        connectionStatus!(true);
        verify(() => mockClient.sendClientContent(
              role: 'user',
              text: any(
                named: 'text',
                that: allOf(contains('czeska polivka'), contains(LiveTutorPrompts.answerAfterReconnect)),
              ),
              turnComplete: true,
            )).called(1);
        expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);

        await agent.stopSession('test');
      });

      testWidgets('the student speaking when the wait runs out postpones the reconnect', (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        await speakAndPause(tester);
        await tester.pump(const Duration(seconds: 10));
        // Student mluví ještě ve chvíli, kdy lhůta doběhne
        speak();
        await tester.pump(const Duration(seconds: 1));
        speak(3);
        verifyNever(() => mockClient.forceReconnect());

        mic(quiet);
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pump(const Duration(milliseconds: 4800));
        verifyNever(() => mockClient.forceReconnect());
        await tester.pump(const Duration(milliseconds: 300));
        verify(() => mockClient.forceReconnect()).called(1);

        await agent.stopSession('test');
      });

      testWidgets('an end of speech the server never confirmed restores the connection right away',
          (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        // Tah se ztratil (lekce 19: server konec řeči nepotvrdil), student by čekal 11 s
        await speakAndPause(tester);
        userTranscript!('I watch the series.');
        activityEndUnconfirmed!();
        verify(() => mockClient.forceReconnect()).called(1);

        connectionStatus!(true);
        verify(() => mockClient.sendClientContent(
              role: 'user',
              text: any(
                named: 'text',
                that: allOf(contains('I watch the series.'), contains(LiveTutorPrompts.answerAfterReconnect)),
              ),
              turnComplete: true,
            )).called(1);

        await agent.stopSession('test');
      });

      testWidgets('an unconfirmed end after the tutor already replied changes nothing', (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        await speakAndPause(tester);
        tutorText!('Sure!');
        activityEndUnconfirmed!();
        verifyNever(() => mockClient.forceReconnect());

        await agent.stopSession('test');
      });

      group('director whisper', () {
        late _CapturingDirector director;
        late List<String> sentContent;

        setUp(() {
          director = _CapturingDirector();
          sentContent = [];
          when(() => mockClient.sendClientContent(
                role: any(named: 'role'),
                text: any(named: 'text'),
                turnComplete: any(named: 'turnComplete'),
              )).thenAnswer((invocation) => sentContent.add(invocation.namedArguments[#text] as String));
          container.dispose();
          container = ProviderContainer(
            overrides: [...overrides, voiceDirectorAgentProvider.overrideWith(() => director)],
          );
        });

        /// Jedna výměna: student promluví, tutor odpoví a domluví.
        Future<void> exchange(WidgetTester tester, String student, String tutor) async {
          await speakAndPause(tester);
          userTranscript!(student);
          tutorText!(tutor);
          turnComplete!();
          await tester.pump();
        }

        bool whisperSent(String whisper) => sentContent.any((text) => text.contains(whisper));

        testWidgets('a whisper ready after one student reply reaches the tutor', (tester) async {
          final agent = container.read(voiceTutorAgentProvider.notifier);
          await agent.startSession();
          await exchange(tester, 'I went to the lake.', 'Nice! Who did you go with?');
          final whisperFromFirstTurn = director.whisperCallbacks.first;

          await exchange(tester, 'With my wife.', 'Lovely! Was the water warm?');
          whisperFromFirstTurn('Ask about the boat.');
          await exchange(tester, 'Yes, quite warm.', 'Great!');
          expect(whisperSent('Ask about the boat.'), isTrue);

          await agent.stopSession('test');
        });

        testWidgets('a whisper that arrives after the student spoke twice is dropped', (tester) async {
          // Lekce 19: rada „přejdi na narozeniny“ dorazila po pěti tazích, zrovna když se student loučil
          final agent = container.read(voiceTutorAgentProvider.notifier);
          await agent.startSession();
          await exchange(tester, 'I went to the lake.', 'Nice! Who did you go with?');
          final whisperFromFirstTurn = director.whisperCallbacks.first;

          await exchange(tester, 'With my wife.', 'Lovely! Was the water warm?');
          await exchange(tester, 'Yes, quite warm.', 'Great! Anything else?');
          whisperFromFirstTurn('Ask about the boat.');
          await exchange(tester, 'Bye, good night.', 'Good night!');
          expect(whisperSent('Ask about the boat.'), isFalse);

          await agent.stopSession('test');
        });
      });

      testWidgets('a reply from the tutor ends the wait', (tester) async {
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        await speakAndPause(tester);
        tutorText!('Sure!');
        await tester.pump(const Duration(seconds: 12));
        verifyNever(() => mockClient.forceReconnect());

        await agent.stopSession('test');
      });

      testWidgets('a reconnect for the token limit restores the conversation context', (tester) async {
        when(() => mockClient.currentTokenCount).thenReturn(26000);
        final agent = container.read(voiceTutorAgentProvider.notifier);
        await agent.startSession();

        await speakAndPause(tester);
        userTranscript!('I like cooking.');
        tutorText!('Nice! What do you cook?');
        turnComplete!();
        verify(() => mockClient.forceReconnect()).called(1);
        expect(container.read(voiceTutorAgentProvider).status, TutorState.reconnecting);

        // Dřív nové spojení znalo jen systémový prompt („Would you like to continue in English?“)
        connectionStatus!(true);
        verify(() => mockClient.sendClientContent(
              role: 'user',
              text: any(named: 'text', that: contains('What do you cook?')),
              turnComplete: false,
            )).called(1);
        expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);

        await agent.stopSession('test');
      });
    });
  });
}
