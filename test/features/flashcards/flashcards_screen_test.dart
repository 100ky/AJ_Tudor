import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/flashcards/flashcards_screen.dart';
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';

class MockGeminiTtsService extends Mock implements GeminiTtsService {}
class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockGeminiTtsService mockTts;
  late MockGeminiBatchClient mockBatchClient;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockTts = MockGeminiTtsService();
    mockBatchClient = MockGeminiBatchClient();

    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
    when(() => mockBatchClient.sendMessage(any())).thenAnswer((_) async => 'Český překlad');
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

  Future<void> typeAnswer(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Odeslat odpověď'));
    await tester.pumpAndSettle();
  }

  Future<void> giveUp(WidgetTester tester) async {
    await tester.tap(find.text('Nevím – ukázat řešení'));
    await tester.pumpAndSettle();
  }

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
        geminiTtsServiceProvider.overrideWithValue(mockTts),
        geminiBatchClientProvider.overrideWithValue(mockBatchClient),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const FlashcardsScreen(),
      ),
    );
  }

  group('FlashcardsScreen Widget Tests', () {
    testWidgets('renders empty state when there are no flashcards in database',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Žádné kartičky k procvičení'), findsOneWidget);
      expect(find.text('Zkontrolovat nové chyby z konverzací'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('renders front of due flashcard with progress header',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Včera jsem šel do kina na nový film.',
              backText: 'Yesterday I went to the cinema to see a new movie.',
              explanation: 'Použijeme minulý čas (went) namísto přítomného (go).',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Progress header
      expect(find.text('Kartička 1 z 1'), findsOneWidget);

      // Front card content
      expect(find.text('Včera jsem šel do kina na nový film.'), findsOneWidget);

      // Bez pokusu o odpověď není tlačítko pro otočení, jen odpověď nebo „Nevím“
      expect(find.text('Otočit kartičku (Zobrazit řešení)'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Nevím – ukázat řešení'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('flips card to reveal back text and SRS rating buttons',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Mám opravdu velký hlad.',
              backText: 'I am really very hungry.',
              explanation: 'V angličtině se používá sloveso to be.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Napsaná odpověď otočí kartičku
      await typeAnswer(tester, 'I am very hungry');

      // Back card content
      expect(find.text('SPRÁVNÉ ŘEŠENÍ'), findsOneWidget);
      expect(find.text('I am really very hungry.'), findsOneWidget);
      expect(find.text('I am very hungry'), findsOneWidget);
      expect(find.text('TVOJE ODPOVĚĎ · SHODA 70 %'), findsOneWidget);
      // 70 % shody doporučí „Dobré“
      expect(find.text('DOPORUČENO'), findsOneWidget);

      // SRS rating buttons
      expect(find.text('Znovu'), findsOneWidget);
      expect(find.text('Těžké'), findsOneWidget);
      expect(find.text('Dobré'), findsOneWidget);
      expect(find.text('Snadné'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('plays TTS pronunciation when speaker button is tapped on back card',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Přelož: Dobré ráno',
              backText: 'Good morning',
              explanation: 'Základní pozdrav.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await giveUp(tester);

      // Find speaker icon
      final speakerButton = find.byTooltip('Přehrát rodilou výslovnost (Gemini TTS)');
      expect(speakerButton, findsOneWidget);

      await tester.tap(speakerButton);
      await tester.pumpAndSettle();

      verify(() => mockTts.speak('Good morning')).called(1);

      await drainTimers(tester);
    });

    testWidgets('reviews flashcard and transitions to session completed state',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Přelož: Děkuji',
              backText: 'Thank you',
              explanation: 'Poděkování.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await typeAnswer(tester, 'Thank you');

      // Rate card as "Dobré"
      await tester.tap(find.text('Dobré'));
      await tester.pumpAndSettle();

      // Session should now be completed
      expect(find.text('Skvělá práce! Relace dokončena'), findsOneWidget);
      expect(find.text('Všechny kartičky z této studijní dávky máš úspěšně procvičené.'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('session completed state renders without overflow on narrow screen (360dp)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Jedna',
              backText: 'One',
              explanation: 'Číslovka 1.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Dva',
              backText: 'Two',
              explanation: 'Číslovka 2.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // First card: "Nevím" and rate "Znovu"
      await giveUp(tester);
      await tester.tap(find.text('Znovu'));
      await tester.pumpAndSettle();

      // Second card: answer and rate "Dobré"
      await typeAnswer(tester, 'Two');
      await tester.tap(find.text('Dobré'));
      await tester.pumpAndSettle();

      // Re-queued first card: answer and rate "Dobré" to finish session
      await typeAnswer(tester, 'One');
      await tester.tap(find.text('Dobré'));
      await tester.pumpAndSettle();

      // Session completed state should show both badges without RenderFlex overflow
      expect(find.text('Skvělá práce! Relace dokončena'), findsOneWidget);
      expect(find.text('2 zvládnuto'), findsOneWidget);
      expect(find.text('1 zopakováno'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await drainTimers(tester);
    });

    testWidgets('shows delete confirmation dialog and deletes card from database',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      final cardId = await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'K smazání',
              backText: 'To be deleted',
              explanation: 'Test mazání.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Flip card to reveal delete button
      await giveUp(tester);

      final deleteButton = find.byTooltip('Smazat tuto kartičku');
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Smazat kartičku?'), findsOneWidget);

      // Confirm delete
      final confirmDelete = find.widgetWithText(FilledButton, 'Smazat');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      // Verify card was deleted from database
      final remainingCards = await db.select(db.flashcards).get();
      expect(remainingCards.any((c) => c.id == cardId), isFalse);

      await drainTimers(tester);
    });

    testWidgets('card cannot be flipped without an answer attempt',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Mám hlad.',
              backText: 'I am hungry.',
              explanation: 'Sloveso to be.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Klepnutí na kartičku bez odpovědi ji neotočí
      await tester.tap(find.text('Mám hlad.'));
      await tester.pumpAndSettle();

      expect(find.text('SPRÁVNÉ ŘEŠENÍ'), findsNothing);
      expect(find.text('Znovu'), findsNothing);

      // Prázdnou odpověď nejde odeslat
      await tester.tap(find.byTooltip('Odeslat odpověď'));
      await tester.pumpAndSettle();
      expect(find.text('SPRÁVNÉ ŘEŠENÍ'), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('"Nevím" reveals the solution but allows only "Znovu"',
        (WidgetTester tester) async {
      configureViewport(tester);
      final now = DateTime.now();
      final cardId = await db.into(db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: 'Uniknout',
              backText: 'escape',
              explanation: 'Sloveso.',
              nextReviewAt: now.subtract(const Duration(hours: 1)),
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await giveUp(tester);
      expect(find.text('SPRÁVNÉ ŘEŠENÍ'), findsOneWidget);

      // „Snadné“ je zakázané, kartička zůstane neohodnocená
      await tester.tap(find.text('Snadné'));
      await tester.pumpAndSettle();
      expect(find.text('SPRÁVNÉ ŘEŠENÍ'), findsOneWidget);
      final unchanged = await (db.select(db.flashcards)..where((c) => c.id.equals(cardId))).getSingle();
      expect(unchanged.repetitionCount, 0);

      // „Znovu“ funguje a kartička se vrátí na konec relace
      await tester.tap(find.text('Znovu'));
      await tester.pumpAndSettle();
      expect(find.text('Kartička 2 z 2'), findsOneWidget);
      expect(find.text('Uniknout'), findsOneWidget);

      await drainTimers(tester);
    });
  });
}
