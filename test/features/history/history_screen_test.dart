import 'package:intl/date_symbol_data_local.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/features/history/history_screen.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/core/utils/result.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/providers/profile_provider.dart';
import 'package:aj_tudor/services/agents/memory_manager_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';

class MockMemoryManagerAgent extends Mock implements MemoryManagerAgent {}
class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}
class MockGeminiTtsService extends Mock implements GeminiTtsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockMemoryManagerAgent mockMemory;
  late MockGeminiBatchClient mockBatchClient;
  late MockGeminiTtsService mockTts;

  setUp(() async {
    await initializeDateFormatting('cs', null);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockMemory = MockMemoryManagerAgent();
    mockBatchClient = MockGeminiBatchClient();
    mockTts = MockGeminiTtsService();

    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        memoryManagerAgentProvider.overrideWithValue(mockMemory),
        geminiBatchClientProvider.overrideWithValue(mockBatchClient),
        geminiTtsServiceProvider.overrideWithValue(mockTts),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const HistoryScreen(),
      ),
    );
  }

  group('HistoryScreen Tests', () {
    testWidgets('renders empty state when there are no past sessions', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Historie konverzací'), findsOneWidget);
      expect(find.text('Zatím nemáš žádné lekce.'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('renders session list with topic summary, duration and error count',
        (WidgetTester tester) async {
      final now = DateTime.now();
      // Insert test session into real in-memory Drift db
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 5)),
              endedAt: Value(now),
              topicSummary: const Value('Cestování letadlem'),
              totalErrors: const Value(2),
              fluencyScore: const Value(85),
            ),
          );

      expect(sessionId, greaterThan(0));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Session card should be visible
      expect(find.byType(SessionCard), findsOneWidget);
      expect(find.text('Cestování letadlem'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('2 chyb'), findsOneWidget);
      expect(find.text('Zobrazit přepis'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('opens session detail modal when session card is tapped', (WidgetTester tester) async {
      final now = DateTime.now();
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 3)),
              endedAt: Value(now),
              topicSummary: const Value('V restauraci'),
              totalErrors: const Value(0),
              fluencyScore: const Value(95),
            ),
          );

      // Add a transcript
      await repo.addTranscript(
        sessionId: sessionId,
        speaker: 'user',
        content: 'I would like a cup of coffee, please.',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on the session card
      await tester.tap(find.byType(SessionCard));
      await tester.pumpAndSettle();

      // Detail bottom sheet is opened
      expect(find.text('V restauraci'), findsWidgets);
      expect(find.text('I would like a cup of coffee, please.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('shows delete confirmation dialog and cancels without deleting',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 2)),
              endedAt: Value(now),
              topicSummary: const Value('Práce a pohovor'),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap delete button directly on session card
      final deleteIcon = find.byTooltip('Smazat lekci');
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Smazat lekci?'), findsOneWidget);
      expect(find.text('Zrušit'), findsOneWidget);

      // Tap Zrušit
      await tester.tap(find.text('Zrušit'));
      await tester.pumpAndSettle();

      // Dialog is dismissed, session still exists in DB
      final allSessions = await db.select(db.sessions).get();
      expect(allSessions.any((s) => s.id == sessionId), isTrue);

      await drainTimers(tester);
    });

    testWidgets('deletes session when confirmed in delete dialog from detail sheet', (WidgetTester tester) async {
      final now = DateTime.now();
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: now.subtract(const Duration(minutes: 2)),
              endedAt: Value(now),
              topicSummary: const Value('Lekce k odstranění'),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byType(SessionCard));
      await tester.pumpAndSettle();

      // Tap delete in detail sheet (the top-most / last one rendered)
      await tester.tap(find.byTooltip('Smazat lekci').last);
      await tester.pumpAndSettle();

      // Tap Smazat in AlertDialog
      final confirmDeleteButton = find.widgetWithText(TextButton, 'Smazat');
      await tester.tap(confirmDeleteButton);
      await tester.pumpAndSettle();

      // Verify session was deleted from database
      final allSessions = await db.select(db.sessions).get();
      expect(allSessions.any((s) => s.id == sessionId), isFalse);

      // History should now show empty state
      expect(find.text('Zatím nemáš žádné lekce.'), findsOneWidget);

      await drainTimers(tester);
    });
  });
}
