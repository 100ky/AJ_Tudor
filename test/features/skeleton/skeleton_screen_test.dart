import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/features/skeleton/skeleton_screen.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';
import 'package:aj_tudor/services/gemini/translation_service.dart';

class MockVoiceTutorAgent extends VoiceTutorAgent {
  final TutorState initialStatus;
  MockVoiceTutorAgent({this.initialStatus = TutorState.idle});

  @override
  VoiceTutorState build() => VoiceTutorState(status: initialStatus);
}

class FakeApiKeyNotifier extends ApiKeyNotifier {
  final String? initialKey;
  FakeApiKeyNotifier(this.initialKey);

  @override
  String? build() => initialKey;
}

class FakeApiKeyLoadedNotifier extends ApiKeyLoadedNotifier {
  final bool initialLoaded;
  FakeApiKeyLoadedNotifier(this.initialLoaded);

  @override
  bool build() => initialLoaded;
}

class MockTopicPreparationAgent extends TopicPreparationAgent {
  bool prepareTopicCalled = false;

  @override
  TopicPreparationState build() => const TopicPreparationState();

  @override
  Future<void> prepareTopic({
    bool force = false,
    bool resetCounter = false,
    bool? isRandomTopic,
  }) async {
    prepareTopicCalled = true;
  }
}

class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}
class MockGeminiTtsService extends Mock implements GeminiTtsService {}
class MockWordTranslationService extends Mock implements WordTranslationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockScenarioPlannerAgent mockScenarioPlanner;
  late MockGeminiTtsService mockTts;
  late MockWordTranslationService mockTranslation;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({
      'gemini_voice': 'Puck',
      'speech_silence_duration_ms': 1500,
    });
    prefs = await SharedPreferences.getInstance();
    mockScenarioPlanner = MockScenarioPlannerAgent();
    mockTts = MockGeminiTtsService();
    mockTranslation = MockWordTranslationService();

    when(() => mockScenarioPlanner.planScenarios()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({
    String? apiKey,
    bool isApiKeyLoaded = true,
    TutorState tutorStatus = TutorState.idle,
    MockTopicPreparationAgent? topicAgent,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiKeyProvider.overrideWith(() => FakeApiKeyNotifier(apiKey)),
        isApiKeyLoadedProvider.overrideWith(() => FakeApiKeyLoadedNotifier(isApiKeyLoaded)),
        voiceTutorAgentProvider.overrideWith(() => MockVoiceTutorAgent(initialStatus: tutorStatus)),
        topicPreparationAgentProvider.overrideWith(() => topicAgent ?? MockTopicPreparationAgent()),
        scenarioPlannerAgentProvider.overrideWithValue(mockScenarioPlanner),
        geminiTtsServiceProvider.overrideWithValue(mockTts),
        wordTranslationServiceProvider.overrideWithValue(mockTranslation),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SkeletonScreen(),
      ),
    );
  }

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('SkeletonScreen Tests', () {
    testWidgets('renders initial screen with 5 navigation destinations', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(apiKey: 'test-api-key'),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SkeletonScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      expect(find.text('Hlas'), findsOneWidget);
      expect(find.text('Dril'), findsOneWidget);
      expect(find.text('Kartičky'), findsOneWidget);
      expect(find.text('Pokrok'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      // Warning banner should NOT be present when API key exists
      expect(find.text('Chybí Gemini API klíč'), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('switches tabs when destination items are tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(apiKey: 'test-api-key'),
      );
      await tester.pump(const Duration(milliseconds: 350));

      // Tap on 'Dril' tab (index 1)
      await tester.tap(find.text('Dril'));
      await tester.pump(const Duration(milliseconds: 350));

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);

      // Tap on 'Kartičky' tab (index 2)
      await tester.tap(find.text('Kartičky'));
      await tester.pump(const Duration(milliseconds: 350));

      final navBar2 = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar2.selectedIndex, 2);

      // Tap on 'Pokrok' tab (index 3)
      await tester.tap(find.text('Pokrok'));
      await tester.pump(const Duration(milliseconds: 350));

      final navBar3 = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar3.selectedIndex, 3);

      // Tap on 'Profil' tab (index 4)
      await tester.tap(find.text('Profil'));
      await tester.pump(const Duration(milliseconds: 350));

      final navBar4 = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar4.selectedIndex, 4);

      await drainTimers(tester);
    });

    testWidgets('displays warning banner when API key is missing and navigates to settings on tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(apiKey: null, isApiKeyLoaded: true),
      );
      await tester.pump(const Duration(milliseconds: 350));

      // Warning banner is displayed
      expect(find.text('Chybí Gemini API klíč'), findsOneWidget);
      expect(find.text('NASTAVIT'), findsOneWidget);

      // Tap on NASTAVIT
      await tester.tap(find.text('NASTAVIT'));
      await tester.pump(const Duration(milliseconds: 350));

      // Should have switched to settings tab (index 4)
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 4);

      // And on tab 4, the warning banner is hidden
      expect(find.text('Chybí Gemini API klíč'), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('hides bottom navigation bar when voice session is actively listening',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          apiKey: 'test-key',
          tutorStatus: TutorState.listening,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final navContainer = animatedContainers.firstWhere(
        (c) => c.duration == const Duration(milliseconds: 320),
      );

      // When voice is active, height is 0.0
      expect(navContainer.constraints?.maxHeight, 0.0);

      await drainTimers(tester);
    });

    testWidgets('calls topicPreparationAgent.prepareTopic on post frame callback',
        (WidgetTester tester) async {
      final topicAgent = MockTopicPreparationAgent();

      await tester.pumpWidget(
        buildTestWidget(
          apiKey: 'test-key',
          topicAgent: topicAgent,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(topicAgent.prepareTopicCalled, isTrue);

      await drainTimers(tester);
    });
  });
}
