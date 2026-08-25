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
    when(() => mockRepo.closeSession(any())).thenAnswer((_) async => Result.success(null));
    when(() => mockMemory.analyzeSession(any())).thenAnswer((_) async {});
    // disconnect might be called
    when(() => mockClient.disconnect()).thenAnswer((_) {});

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
}
