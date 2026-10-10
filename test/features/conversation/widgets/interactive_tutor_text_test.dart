import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/conversation/widgets/interactive_tutor_text.dart';
import 'package:aj_tudor/services/gemini/translation_service.dart';

void main() {
  group('WordTranslationService Tests', () {
    test('cleanWord strips punctuation and quotes correctly', () {
      expect(WordTranslationService.cleanWord('Hello,'), 'Hello');
      expect(WordTranslationService.cleanWord('amazing!'), 'amazing');
      expect(WordTranslationService.cleanWord('"wonderful"'), 'wonderful');
      expect(WordTranslationService.cleanWord('„předpokládat“'), 'předpokládat');
      expect(WordTranslationService.cleanWord('...really?'), 'really');
      expect(WordTranslationService.cleanWord('  look forward to  '), 'look forward to');
    });
  });

  group('InteractiveTutorText Widget Tests', () {
    testWidgets('renders all words in text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveTutorText(
              text: 'I really enjoy speaking with you.',
              autoOpenTranslationSheet: false,
            ),
          ),
        ),
      );

      expect(find.text('I'), findsOneWidget);
      expect(find.text('really'), findsOneWidget);
      expect(find.text('enjoy'), findsOneWidget);
      expect(find.text('speaking'), findsOneWidget);
      expect(find.text('with'), findsOneWidget);
      expect(find.text('you.'), findsOneWidget);
    });

    testWidgets('tapping a single word triggers onSelection with that word', (tester) async {
      String? selected;
      String? context;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveTutorText(
              text: 'This is an awesome sentence.',
              autoOpenTranslationSheet: false,
              onSelection: (phrase, fullSentence) {
                selected = phrase;
                context = fullSentence;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('awesome'));
      await tester.pumpAndSettle();

      expect(selected, 'awesome');
      expect(context, 'This is an awesome sentence.');
    });

    testWidgets('range selection (tapping two words) joins them into a phrase', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveTutorText(
              text: 'I look forward to meeting you.',
              autoOpenTranslationSheet: false,
              onSelection: (phrase, fullSentence) {
                selected = phrase;
              },
            ),
          ),
        ),
      );

      // Klik na 'look'
      await tester.tap(find.text('look'));
      await tester.pumpAndSettle();

      // Následný klik na 'to'
      await tester.tap(find.text('to'));
      await tester.pumpAndSettle();

      expect(selected, 'look forward to');
    });

    testWidgets('holding a word and dragging selects a phrase', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 250,
              child: InteractiveTutorText(
                text: 'I look forward to meeting you in Prague.',
                autoOpenTranslationSheet: false,
                onSelection: (phrase, fullSentence) {
                  selected = phrase;
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('look')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(find.text('meeting')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, 'look forward to meeting');
    });

    testWidgets('holding and dragging selects words across lines', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 130,
              child: InteractiveTutorText(
                text: 'First line and second line.',
                autoOpenTranslationSheet: false,
                onSelection: (phrase, fullSentence) {
                  selected = phrase;
                },
              ),
            ),
          ),
        ),
      );

      // Start drag on 'First'
      final gesture = await tester.startGesture(tester.getCenter(find.text('First')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Drag down onto 'second' on the next line
      await gesture.moveTo(tester.getCenter(find.text('second')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selected, 'First line and second');
    });

    testWidgets('dragging without holding scrolls the list instead of selecting', (tester) async {
      String? selected;
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < 20; i++)
                  InteractiveTutorText(
                    text: 'Line $i with quite a few English words to read.',
                    autoOpenTranslationSheet: false,
                    onSelection: (phrase, fullSentence) => selected = phrase,
                  ),
              ],
            ),
          ),
        ),
      );

      // Diagonální tah začínající na slově (dřív hned zapnul výběr)
      await tester.dragFrom(tester.getCenter(find.text('English').at(5)), const Offset(-15, -200));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(selected, isNull);
    });

    testWidgets('Czech words are plain text, the English example stays tappable', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveTutorText(
              text: 'Správně je **I have been working** od rána.',
              autoOpenTranslationSheet: false,
              onSelection: (phrase, fullSentence) => selected = phrase,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Správně'));
      await tester.pumpAndSettle();
      expect(selected, isNull);

      await tester.tap(find.text('working'));
      await tester.pumpAndSettle();
      expect(selected, 'working');
    });
  });
}

