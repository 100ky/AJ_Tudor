import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/widgets/interactive_tutor_text.dart';
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
  });
}

