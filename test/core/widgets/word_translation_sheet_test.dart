import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/core/widgets/word_translation_sheet.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/core/utils/result.dart';
import 'package:aj_tudor/services/agents/voice_tutor_agent.dart';
import 'package:aj_tudor/services/gemini/translation_service.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';

class MockWordTranslationService extends Mock implements WordTranslationService {}
class MockGeminiTtsService extends Mock implements GeminiTtsService {}

class TestVoiceTutorAgent extends VoiceTutorAgent {
  final TutorState initialStatus;
  bool pauseCalled = false;
  bool resumeCalled = false;

  TestVoiceTutorAgent({this.initialStatus = TutorState.idle});

  @override
  VoiceTutorState build() => VoiceTutorState(status: initialStatus);

  @override
  Future<void> pauseSession() async {
    pauseCalled = true;
    await Future.microtask(() {});
    state = VoiceTutorState(status: TutorState.paused);
  }

  @override
  Future<void> resumeSession() async {
    resumeCalled = true;
    await Future.microtask(() {});
    state = VoiceTutorState(status: TutorState.listening);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockWordTranslationService mockTranslationService;
  late MockGeminiTtsService mockTtsService;
  late TestVoiceTutorAgent testVoiceAgent;

  setUp(() {
    mockTranslationService = MockWordTranslationService();
    mockTtsService = MockGeminiTtsService();
    testVoiceAgent = TestVoiceTutorAgent(initialStatus: TutorState.idle);

    when(() => mockTtsService.speak(any())).thenAnswer((_) async => true);
    when(() => mockTranslationService.saveToFlashcards(
          englishText: any(named: 'englishText'),
          czechText: any(named: 'czechText'),
          contextSentence: any(named: 'contextSentence'),
        )).thenAnswer((_) async => const Result.success(42));
    when(() => mockTranslationService.removeFromFlashcards(any()))
        .thenAnswer((_) async => const Result.success(null));
  });

  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      overrides: [
        wordTranslationServiceProvider.overrideWithValue(mockTranslationService),
        geminiTtsServiceProvider.overrideWithValue(mockTtsService),
        voiceTutorAgentProvider.overrideWith(() => testVoiceAgent),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('WordTranslationSheet Tests', () {
    testWidgets('shows loading state then displays translation and auto-saves to flashcards',
        (WidgetTester tester) async {
      final completer = Completer<String>();
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        buildTestWidget(
          child: const WordTranslationSheet(
            englishText: 'apple',
            contextSentence: 'I eat an apple every day.',
          ),
        ),
      );

      // Loading indicator present initially
      expect(find.text('Překládám v kontextu věty...'), findsOneWidget);

      // Complete the translation
      completer.complete('jablko');
      await tester.pumpAndSettle();

      // Verify translation is displayed
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('jablko'), findsOneWidget);
      expect(find.text('Uloženo do Smart Flashcards! 🃏'), findsOneWidget);

      verify(() => mockTranslationService.saveToFlashcards(
            englishText: 'apple',
            czechText: 'jablko',
            contextSentence: 'I eat an apple every day.',
          )).called(1);
    });

    testWidgets('displays error message when translation fails', (WidgetTester tester) async {
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) async => 'Překlad se nezdařil');

      await tester.pumpWidget(
        buildTestWidget(
          child: const WordTranslationSheet(
            englishText: 'unknown_word',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Překlad se nepodařilo načíst.'), findsOneWidget);
    });

    testWidgets('plays pronunciation when audio icon is tapped', (WidgetTester tester) async {
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) async => 'ahoj');

      await tester.pumpWidget(
        buildTestWidget(
          child: const WordTranslationSheet(
            englishText: 'hello',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final ttsButton = find.byIcon(Icons.volume_mute_rounded);
      expect(ttsButton, findsOneWidget);

      await tester.tap(ttsButton);
      await tester.pump();

      verify(() => mockTtsService.speak('hello')).called(1);
    });

    testWidgets('allows expanding phrase with left and right buttons', (WidgetTester tester) async {
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) async => 'rychlý běh');

      await tester.pumpWidget(
        buildTestWidget(
          child: const WordTranslationSheet(
            englishText: 'fast',
            contextSentence: 'the quick fast brown fox',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('+ Slovo vlevo'), findsOneWidget);
      expect(find.text('+ Slovo vpravo'), findsOneWidget);

      // Tap + Slovo vpravo
      await tester.tap(find.text('+ Slovo vpravo'));
      await tester.pumpAndSettle();

      // Now english text should include "fast brown"
      expect(find.text('fast brown'), findsOneWidget);
    });

    testWidgets('toggles flashcard from saved to unsaved (Vrátit)', (WidgetTester tester) async {
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) async => 'kočka');

      await tester.pumpWidget(
        buildTestWidget(
          child: const WordTranslationSheet(
            englishText: 'cat',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vrátit ↩'), findsOneWidget);

      // Tap Vrátit ↩
      await tester.tap(find.text('Vrátit ↩'));
      await tester.pumpAndSettle();

      verify(() => mockTranslationService.removeFromFlashcards(42)).called(1);
      expect(find.text('Není v kartičkách'), findsOneWidget);
      expect(find.text('+ Uložit'), findsOneWidget);
    });

    testWidgets('pops the navigator when close button is tapped', (WidgetTester tester) async {
      when(() => mockTranslationService.translate(
            text: any(named: 'text'),
            contextSentence: any(named: 'contextSentence'),
          )).thenAnswer((_) async => 'pes');

      bool popped = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Navigator(
            onPopPage: (route, result) {
              popped = true;
              return route.didPop(result);
            },
            pages: [
              MaterialPage(
                child: Scaffold(
                  body: WordTranslationSheet(
                    englishText: 'dog',
                    onDismissed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
