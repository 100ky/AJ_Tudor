import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/core/widgets/chat_bubble.dart';
import 'package:aj_tudor/core/widgets/smart_chat_bubble.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/conversation/voice_tutor_screen.dart';
import 'package:aj_tudor/features/conversation/widgets/fluid_voice_wave.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';
import 'package:aj_tudor/services/agents/voice_director_agent.dart';
import 'package:aj_tudor/services/audio/audio_session_controller.dart';


class MockAudioSessionController extends Mock implements AudioSessionController {}
class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}

class FakeVoiceTutorAgent extends VoiceTutorAgent {
  final VoiceTutorState initialState;
  bool startSessionCalled = false;
  String? stopSessionReason;
  bool pauseSessionCalled = false;
  bool resumeSessionCalled = false;
  int? selectedId;

  FakeVoiceTutorAgent([VoiceTutorState? state])
      : initialState = state ?? VoiceTutorState();

  @override
  VoiceTutorState build() => initialState;

  @override
  Future<void> startSession({int? scenarioId, String? scenarioContext}) async {
    startSessionCalled = true;
    state = state.copyWith(status: TutorState.listening);
  }

  @override
  Future<void> stopSession([String reason = 'user_ended']) async {
    stopSessionReason = reason;
    state = state.copyWith(status: TutorState.idle);
  }

  @override
  Future<void> pauseSession() async {
    pauseSessionCalled = true;
    state = state.copyWith(status: TutorState.paused);
  }

  @override
  Future<void> resumeSession() async {
    resumeSessionCalled = true;
    state = state.copyWith(status: TutorState.listening);
  }

  @override
  void selectScenario(int? id, String? instruction) {
    selectedId = id;
    state = state.copyWith(selectedScenarioId: id, scenarioContext: instruction);
  }
}

class FakeTopicPreparationAgent extends TopicPreparationAgent {
  final TopicPreparationState initialState;
  FakeTopicPreparationAgent([this.initialState = const TopicPreparationState()]);

  @override
  TopicPreparationState build() => initialState;
}

class FakeSmartBubblesNotifier extends SmartBubblesNotifier {
  final bool initialValue;
  FakeSmartBubblesNotifier([this.initialValue = true]);

  @override
  bool build() => initialValue;
}

class FakeVoiceDirectorAgent extends VoiceDirectorAgent {
  final VoiceDirectorState initialState;
  bool dismissTipCalled = false;
  FakeVoiceDirectorAgent([this.initialState = const VoiceDirectorState()]);

  @override
  VoiceDirectorState build() => initialState;

  @override
  void dismissTip() {
    dismissTipCalled = true;
    state = state.copyWith(clearTip: true);
  }
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockAudioSessionController mockAudio;
  late MockScenarioPlannerAgent mockPlanner;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockAudio = MockAudioSessionController();
    mockPlanner = MockScenarioPlannerAgent();

    when(() => mockAudio.captureVolumeStream).thenAnswer((_) => const Stream.empty());
    when(() => mockAudio.playbackVolumeStream).thenAnswer((_) => const Stream.empty());
    when(() => mockPlanner.planScenarios()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildTestWidget({
    required FakeVoiceTutorAgent fakeTutorAgent,
    FakeVoiceDirectorAgent? fakeDirectorAgent,
    TopicPreparationState? topicState,
    bool smartBubbles = true,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        audioSessionControllerProvider.overrideWithValue(mockAudio),
        scenarioPlannerAgentProvider.overrideWithValue(mockPlanner),
        smartBubblesEnabledProvider.overrideWith(() => FakeSmartBubblesNotifier(smartBubbles)),
        voiceTutorAgentProvider.overrideWith(() => fakeTutorAgent),
        voiceDirectorAgentProvider.overrideWith(() => fakeDirectorAgent ?? FakeVoiceDirectorAgent()),
        topicPreparationAgentProvider
            .overrideWith(() => FakeTopicPreparationAgent(topicState ?? const TopicPreparationState())),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const VoiceTutorScreen(),
      ),
    );
  }

  group('VoiceTutorScreen Widget Tests', () {
    testWidgets('renders idle state with hero header, mode tabs and mic button',
        (WidgetTester tester) async {
      configureViewport(tester);
      final fakeAgent = FakeVoiceTutorAgent(VoiceTutorState(status: TutorState.idle));

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent));
      // FluidVoiceWave & blinking cursor have infinite repeat tickers, use pump() with fixed duration
      await tester.pump(const Duration(milliseconds: 300));

      // Title & Hero header
      expect(find.text('Hlasový Tutor'), findsOneWidget);
      expect(find.byType(FluidVoiceWave), findsOneWidget);

      // Mode switch tabs
      expect(find.text('Historie'), findsOneWidget);
      expect(find.text('Scénáře'), findsOneWidget);
      expect(find.text('Volný'), findsOneWidget);

      // Idle mic button
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('switches mode tabs in idle state', (WidgetTester tester) async {
      configureViewport(tester);
      final fakeAgent = FakeVoiceTutorAgent(VoiceTutorState(status: TutorState.idle));

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent));
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to 'Scénáře' tab
      await tester.tap(find.text('Scénáře'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Vygenerovat scénáře na míru'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Switch to 'Volný' tab
      await tester.tap(find.text('Volný'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Volný pokec o čemkoliv'), findsOneWidget);

      // Switch back to 'Historie' tab
      await tester.tap(find.text('Historie'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Historie'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('taps mic button in idle state and triggers startSession',
        (WidgetTester tester) async {
      configureViewport(tester);
      final fakeAgent = FakeVoiceTutorAgent(VoiceTutorState(status: TutorState.idle));

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent));
      await tester.pump(const Duration(milliseconds: 300));

      final micButton = find.byIcon(Icons.mic_rounded);
      expect(micButton, findsOneWidget);

      await tester.tap(micButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAgent.startSessionCalled, isTrue);

      await drainTimers(tester);
    });

    testWidgets('displays active call controls and messages in active state',
        (WidgetTester tester) async {
      configureViewport(tester);
      final activeMessages = [
        ChatMessage(
          'Good morning Tudor!',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
        ),
        ChatMessage(
          'Good morning! How are you feeling today?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      ];

      final fakeAgent = FakeVoiceTutorAgent(
        VoiceTutorState(
          status: TutorState.speaking,
          messages: activeMessages,
        ),
      );

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent, smartBubbles: false));
      await tester.pump(const Duration(milliseconds: 300));

      // In active state, stop and pause buttons should be visible
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Messages rendered as ChatBubble when smartBubbles is false
      expect(find.byType(ChatBubble), findsNWidgets(2));
      expect(find.text('Good morning Tudor!'), findsOneWidget);
      expect(find.text('morning!'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('renders SmartChatBubble when smartBubbles is enabled',
        (WidgetTester tester) async {
      configureViewport(tester);
      final activeMessages = [
        ChatMessage(
          'Hello Tudor',
          isUser: true,
        ),
      ];

      final fakeAgent = FakeVoiceTutorAgent(
        VoiceTutorState(
          status: TutorState.listening,
          messages: activeMessages,
        ),
      );

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent, smartBubbles: true));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SmartChatBubble), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('pauses and stops session from active call controls',
        (WidgetTester tester) async {
      configureViewport(tester);
      final fakeAgent = FakeVoiceTutorAgent(
        VoiceTutorState(status: TutorState.listening),
      );

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap pause button
      final pauseButton = find.byIcon(Icons.pause_rounded);
      expect(pauseButton, findsOneWidget);
      await tester.tap(pauseButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAgent.pauseSessionCalled, isTrue);

      // Tap stop button
      final stopButton = find.byIcon(Icons.stop_rounded);
      expect(stopButton, findsOneWidget);
      await tester.tap(stopButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeAgent.stopSessionReason, isNotNull);

      await drainTimers(tester);
    });

    testWidgets('displays error card when errorMessage is present in tutorState',
        (WidgetTester tester) async {
      configureViewport(tester);
      final fakeAgent = FakeVoiceTutorAgent(
        VoiceTutorState(
          status: TutorState.error,
          errorMessage: 'Nepodařilo se připojit k mikrofonu.',
        ),
      );

      await tester.pumpWidget(buildTestWidget(fakeTutorAgent: fakeAgent));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nepodařilo se připojit k mikrofonu.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('renders director tip banner in active call and dismisses on close tap',
        (WidgetTester tester) async {
      configureViewport(tester);
      final fakeTutor = FakeVoiceTutorAgent(
        VoiceTutorState(
          status: TutorState.listening,
          messages: [
            ChatMessage('I really enjoy cycling in Prague.', isUser: true),
            ChatMessage('Prague has wonderful bike trails along the river!', isUser: false),
          ],
        ),
      );
      final fakeDirector = FakeVoiceDirectorAgent(
        const VoiceDirectorState(currentTip: 'Ask Tudor: Do you have a pet?'),
      );

      await tester.pumpWidget(buildTestWidget(
        fakeTutorAgent: fakeTutor,
        fakeDirectorAgent: fakeDirector,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ask Tudor: Do you have a pet?'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeDirector.dismissTipCalled, isTrue);

      await drainTimers(tester);
    });
  });
}
