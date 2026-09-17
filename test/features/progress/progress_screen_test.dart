import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/history/history_screen.dart';
import 'package:aj_tudor/features/progress/progress_screen.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:fl_chart/fl_chart.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}
class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockGeminiBatchClient mockBatchClient;
  late MockScenarioPlannerAgent mockPlanner;

  setUp(() async {
    await initializeDateFormatting('cs', null);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockBatchClient = MockGeminiBatchClient();
    mockPlanner = MockScenarioPlannerAgent();

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

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        geminiBatchClientProvider.overrideWithValue(mockBatchClient),
        scenarioPlannerAgentProvider.overrideWithValue(mockPlanner),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const ProgressScreen(),
      ),
    );
  }

  group('ProgressScreen Tests', () {
    testWidgets('renders initial overview tab with summary grid and flashcard stats',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('Tvůj pokrok'), findsOneWidget);

      // Segmented control tabs
      expect(find.text('Přehled a vývoj'), findsOneWidget);
      expect(find.text('Historie lekcí'), findsOneWidget);

      // Summary grid items
      expect(find.text('Lekce'), findsOneWidget);
      expect(find.text('Čas'), findsOneWidget);
      expect(find.text('Slovíčka'), findsOneWidget);
      expect(find.text('Aktivní dny'), findsOneWidget);

      // Flashcards mastery card
      expect(find.text('Stav cvičebny & kartiček'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('switches to Historie lekcí tab and displays empty state when no sessions',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on 'Historie lekcí' tab segment
      await tester.tap(find.text('Historie lekcí'));
      await tester.pumpAndSettle();

      // Verify empty state in history tab
      expect(find.text('Zatím nemáš žádné lekce'), findsOneWidget);
      expect(find.text('Spusť svou první hlasovou lekci v záložce Hlas.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('renders session list in Historie lekcí tab when sessions exist',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 15)),
              endedAt: Value(now),
              topicSummary: const Value('Příprava na pracovní pohovor'),
              fluencyScore: const Value(0.88),
              totalErrors: const Value(0),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to history tab
      await tester.tap(find.text('Historie lekcí'));
      await tester.pumpAndSettle();

      // Verify session card is displayed
      expect(find.byType(SessionCard), findsOneWidget);
      expect(find.text('Příprava na pracovní pohovor'), findsOneWidget);
      expect(find.text('Bez chyb 🎉'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays fluency chart and calculated stats when sessions exist',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();

      // Insert 2 sessions
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
              endedAt: Value(now.subtract(const Duration(hours: 2))),
              topicSummary: const Value('Lekce 1: Cestování'),
              fluencyScore: const Value(0.70),
              totalErrors: const Value(3),
            ),
          );
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 10)),
              endedAt: Value(now),
              topicSummary: const Value('Lekce 2: Restaurace'),
              fluencyScore: const Value(0.85),
              totalErrors: const Value(1),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Overview tab should show fluency chart
      expect(find.text('Vývoj plynulosti'), findsOneWidget);
      expect(find.text('85% naposledy'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);

      // Summary grid total time (20m + 10m = 30m)
      expect(find.text('30m'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays error distribution chart and recent errors when error logs exist',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 10)),
              endedAt: Value(now),
              topicSummary: const Value('Gramatika'),
              fluencyScore: const Value(0.75),
              totalErrors: const Value(2),
            ),
          );

      // Insert error logs
      await db.into(db.errorLogs).insert(
            ErrorLogsCompanion.insert(
              sessionId: sessionId,
              errorType: 'grammar',
              userSaid: 'I goes there yesterday',
              correctForm: 'I went there yesterday',
              explanation: 'Past tense of go is went.',
              timestamp: now,
            ),
          );
      await db.into(db.errorLogs).insert(
            ErrorLogsCompanion.insert(
              sessionId: sessionId,
              errorType: 'vocabulary',
              userSaid: 'I have hunger',
              correctForm: 'I am hungry',
              explanation: 'In English we say I am hungry.',
              timestamp: now,
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Expand error distribution accordion
      expect(find.text('Rozložení chyb'), findsOneWidget);
      await tester.tap(find.text('Rozložení chyb'));
      await tester.pumpAndSettle();

      expect(find.byType(PieChart), findsOneWidget);

      // Expand recent errors section
      expect(find.text('Nedávné chyby'), findsOneWidget);
      await tester.tap(find.text('Nedávné chyby'));
      await tester.pumpAndSettle();

      expect(find.text('I goes there yesterday'), findsOneWidget);
      expect(find.text('I went there yesterday'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays memory briefing and vocabulary cards when profile has data',
        (WidgetTester tester) async {
      configureViewport(tester);
      final vocabJson = jsonEncode(['subtle', 'negotiate', 'compromise']);
      await db.into(db.userProfiles).insert(
            UserProfilesCompanion.insert(
              targetLevel: const Value('C1'),
              memoryBriefing: const Value('Student se připravuje na manažerskou schůzku.'),
              vocabulary: Value(vocabJson),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Expand memory briefing
      expect(find.text('Co si tutor pamatuje'), findsOneWidget);
      await tester.tap(find.text('Co si tutor pamatuje'));
      await tester.pumpAndSettle();

      expect(find.text('Student se připravuje na manažerskou schůzku.'), findsOneWidget);

      // Expand vocabulary
      expect(find.text('Slovní zásoba'), findsWidgets);
      await tester.tap(find.text('3 slov'));
      await tester.pumpAndSettle();

      expect(find.text('subtle'), findsOneWidget);
      expect(find.text('negotiate'), findsOneWidget);
      expect(find.text('compromise'), findsOneWidget);

      await drainTimers(tester);
    });
  });
}
