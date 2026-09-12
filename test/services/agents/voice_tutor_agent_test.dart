import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_live_client.dart';
import 'package:aj_tudor/services/audio/audio_session_controller.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/services/agents/memory_manager_agent.dart';
import 'package:aj_tudor/services/system/wakelock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aj_tudor/core/utils/result.dart';

class MockGeminiLiveClient extends Mock implements GeminiLiveClient {}
class MockAudioSessionController extends Mock implements AudioSessionController {}
class MockSessionRepository extends Mock implements SessionRepository {}
class MockMemoryManagerAgent extends Mock implements MemoryManagerAgent {}
class MockWakelockService extends Mock implements WakelockService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late ProviderContainer container;
  late MockGeminiLiveClient mockClient;
  late MockAudioSessionController mockAudio;
  late MockSessionRepository mockRepo;
  late MockMemoryManagerAgent mockMemory;
  late MockWakelockService mockWakelock;
  late MockSharedPreferences mockPrefs;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockClient = MockGeminiLiveClient();
    mockAudio = MockAudioSessionController();
    mockRepo = MockSessionRepository();
    mockMemory = MockMemoryManagerAgent();
    mockWakelock = MockWakelockService();
    mockPrefs = MockSharedPreferences();
    mockStorage = MockFlutterSecureStorage();

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
    )).thenAnswer((_) async => Result.success(null));
    when(() => mockMemory.analyzeSession(any())).thenAnswer((_) async {});
    // disconnect might be called
    when(() => mockClient.disconnect()).thenAnswer((_) {});
    when(() => mockClient.isConnected).thenReturn(true);

    container = ProviderContainer(
      overrides: [
        geminiLiveClientProvider.overrideWithValue(mockClient),
        audioSessionControllerProvider.overrideWithValue(mockAudio),
        sessionRepositoryProvider.overrideWithValue(mockRepo),
        memoryManagerAgentProvider.overrideWithValue(mockMemory),
        wakelockServiceProvider.overrideWithValue(mockWakelock),
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        secureStorageProvider.overrideWithValue(mockStorage),
      ],
    );
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
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
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
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
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
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
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

  test('interruptPlayback stops audio playback and returns state to listening', () async {
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockAudio.isPlaying).thenReturn(true);
    when(() => mockAudio.stopPlayback()).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
      silenceDurationMs: any(named: 'silenceDurationMs'),
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

  test('startSession passes configured silenceDurationMs to client.connect', () async {
    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
      silenceDurationMs: any(named: 'silenceDurationMs'),
    )).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    verify(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
      silenceDurationMs: 1500, // default from SpeechPatienceNotifier
    )).called(1);
  });

  test('long user speech: receiving multiple STT chunks does not trigger premature nudgeModel or forceReconnect', () async {
    Function(String)? userTranscriptCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((_) async {});
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
      silenceDurationMs: any(named: 'silenceDurationMs'),
    )).thenAnswer((_) {});
    when(() => mockClient.nudgeModel()).thenAnswer((_) {});
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

    // Crucially: nudgeModel and forceReconnect must NOT be called while user is receiving transcripts!
    verifyNever(() => mockClient.nudgeModel());
    verifyNever(() => mockClient.forceReconnect());
  });

  test('audio chunk in thinking state reverts to listening and streams audio', () async {
    Function(List<int>)? audioChunkCallback;

    when(() => mockRepo.startNewSession()).thenAnswer((_) async => Result.success(123));
    when(() => mockRepo.getUserProfile()).thenAnswer((_) async => null);
    when(() => mockAudio.isPlaying).thenReturn(false);
    when(() => mockAudio.start(onAudioChunk: any(named: 'onAudioChunk'))).thenAnswer((invocation) async {
      audioChunkCallback = invocation.namedArguments[const Symbol('onAudioChunk')] as Function(List<int>)?;
    });
    when(() => mockClient.connect(
      modelName: any(named: 'modelName'),
      systemPrompt: any(named: 'systemPrompt'),
      voiceName: any(named: 'voiceName'),
      silenceDurationMs: any(named: 'silenceDurationMs'),
    )).thenAnswer((_) {});
    when(() => mockClient.sendAudioChunk(any())).thenAnswer((_) {});
    when(() => mockClient.sendText(any())).thenAnswer((_) {});

    final agent = container.read(voiceTutorAgentProvider.notifier);
    await agent.startSession();

    expect(audioChunkCallback, isNotNull);

    // Manually put into thinking state (as if waiting for tutor response)
    agent.sendText('Thinking test');
    expect(container.read(voiceTutorAgentProvider).status, TutorState.thinking);

    // User speaks again (generates 16-bit PCM buffer with audible volume)
    final audioBuffer = List<int>.filled(640, 50); // PCM samples
    audioChunkCallback!(audioBuffer);

    // State should revert to listening and audio should be streamed to client
    expect(container.read(voiceTutorAgentProvider).status, TutorState.listening);
    verify(() => mockClient.sendAudioChunk(audioBuffer)).called(1);
  });
}

