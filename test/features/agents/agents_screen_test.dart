import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/agents/agents_screen.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';

class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}

class FakeVoiceTutorAgent extends VoiceTutorAgent {
  final VoiceTutorState initialState;
  FakeVoiceTutorAgent([VoiceTutorState? state])
      : initialState = state ?? VoiceTutorState();

  @override
  VoiceTutorState build() => initialState;
}

class FakeTopicPreparationAgent extends TopicPreparationAgent {
  final TopicPreparationState initialState;
  FakeTopicPreparationAgent([this.initialState = const TopicPreparationState()]);

  @override
  TopicPreparationState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockScenarioPlannerAgent mockPlanner;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockPlanner = MockScenarioPlannerAgent();

    when(() => mockPlanner.planScenarios()).thenAnswer((_) async {});
    when(() => mockPlanner.planCustomScenario(any()))
        .thenAnswer((invocation) async {
      final userHint = invocation.positionalArguments.first as String;
      return Scenario(
        id: 99,
        externalId: 'ext_99',
        title: userHint,
        description: 'Vlastní popis',
        tutorInstruction: 'Instrukce',
        difficulty: 'B1',
        isUsed: false,
        createdAt: DateTime.now(),
      );
    });
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
    VoiceTutorState? tutorState,
    TopicPreparationState? topicState,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        scenarioPlannerAgentProvider.overrideWithValue(mockPlanner),
        voiceTutorAgentProvider.overrideWith(() => FakeVoiceTutorAgent(tutorState)),
        topicPreparationAgentProvider
            .overrideWith(() => FakeTopicPreparationAgent(topicState ?? const TopicPreparationState())),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AgentsScreen(),
      ),
    );
  }

  group('AgentsScreen Tests', () {
    testWidgets('renders all agent cards and initial headers', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('Moji AI Agenti'), findsOneWidget);

      // Header card
      expect(find.text('Multi-agentní systém AJ Tudor'), findsOneWidget);

      // Agent 1: Tutor
      expect(find.text('1. Konverzační Tutor'), findsOneWidget);
      expect(find.text('V POHOTOVOSTI'), findsOneWidget);

      // Agent 2: Analyzer
      expect(find.text('2. Analytik skóre'), findsOneWidget);
      expect(find.text('Plynulost'), findsOneWidget);
      expect(find.text('Zjištěná Úroveň'), findsOneWidget);

      // Agent 3: Planner
      expect(find.text('3. Plánovač témat'), findsOneWidget);
      expect(find.text('Vymyslet nová témata'), findsOneWidget);

      // Agent 4: Startup Topic Agent
      expect(find.text('Startup Topic Agent'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays active tutor state status in TutorAgentCard', (WidgetTester tester) async {
      configureViewport(tester);
      final activeTutorState = VoiceTutorState(status: TutorState.listening);

      await tester.pumpWidget(buildTestWidget(tutorState: activeTutorState));
      await tester.pumpAndSettle();

      // Status badge renders text in uppercase
      expect(find.text('POSLOUCHÁ TĚ...'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays user metrics and memory briefing in Analyzer card', (WidgetTester tester) async {
      configureViewport(tester);
      // Seed user profile and session in DB
      await db.into(db.userProfiles).insert(
            UserProfilesCompanion.insert(
              targetLevel: const Value('B2'),
              memoryBriefing: const Value('Student má psa jménem Rex a rád peče chleba.'),
              recurringErrors: const Value('past tense'),
            ),
          );

      final now = DateTime.now();
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 5)),
              endedAt: Value(now),
              topicSummary: const Value('Pekařství a kynuté těsto'),
              fluencyScore: const Value(0.85),
              totalErrors: const Value(2),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check metrics
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Student má psa jménem Rex a rád peče chleba.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays scenarios when available in database', (WidgetTester tester) async {
      configureViewport(tester);
      // Insert a scenario into the database
      await repo.insertScenario(
        title: 'Návštěva lékaře',
        description: 'Vysvětli lékaři své příznaky a domluv si vyšetření.',
        tutorInstruction: 'Hraj roli britského lékaře.',
        difficulty: 'B1',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Návštěva lékaře'), findsOneWidget);
      expect(find.text('Vysvětli lékaři své příznaky a domluv si vyšetření.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('triggers scenario planning when "Vymyslet nová témata" is tapped',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final planButton = find.widgetWithText(FilledButton, 'Vymyslet nová témata');
      expect(planButton, findsOneWidget);

      await tester.tap(planButton);
      await tester.pump();

      // Verify mock was called
      verify(() => mockPlanner.planScenarios()).called(1);

      await tester.pumpAndSettle();
      expect(find.text('Plánovač témat úspěšně vygeneroval 3 nové scénáře! 🎯'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('creates custom scenario when input is submitted', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'Objednávka v pekárně');
      await tester.pump();

      // Tap send icon button next to the input
      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);

      await tester.tap(sendButton);
      await tester.pump();

      verify(() => mockPlanner.planCustomScenario('Objednávka v pekárně')).called(1);

      await tester.pumpAndSettle();
      expect(find.text('Vlastní scénář „Objednávka v pekárně" úspěšně vytvořen! 🎯'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays prepared topic details when TopicPreparationAgent has a topic',
        (WidgetTester tester) async {
      configureViewport(tester);
      final topicState = TopicPreparationState(
        topic: PreparedTopic(
          title: 'Cestování vlakem do Vídně',
          openerEn: 'Have you ever taken the train to Vienna?',
          rationale: 'Procvičení minulého času a předložek v dopravě.',
          preparedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestWidget(topicState: topicState));
      await tester.pumpAndSettle();

      expect(find.text('Cestování vlakem do Vídně'), findsOneWidget);
      expect(find.text('„Have you ever taken the train to Vienna?“'), findsOneWidget);

      await drainTimers(tester);
    });
  });
}

