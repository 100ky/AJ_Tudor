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
    // disconnect might be called
    when(() => mockClient.disconnect()).thenReturn(null);

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
}
