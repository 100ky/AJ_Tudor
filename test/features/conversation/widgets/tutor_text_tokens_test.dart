import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/conversation/widgets/tutor_text_tokens.dart';

void main() {
  List<String> selectable(String text) => tokenizeTutorText(text)
      .where((t) => t.isSelectableWord)
      .map((t) => t.cleanWord)
      .toList();

  group('tokenizeTutorText', () {
    test('English text is selectable word by word', () {
      expect(selectable('I really enjoy speaking with you.'),
          ['I', 'really', 'enjoy', 'speaking', 'with', 'you']);
    });

    test('Czech sentences are plain text', () {
      expect(selectable('Výborně! Teď přelož tuto větu do angličtiny.'), isEmpty);
      expect(selectable('Zkus to znovu.'), isEmpty);
    });

    test('English example in bold inside a Czech sentence stays selectable', () {
      final tokens = tokenizeTutorText('Správně je **I have been working** od rána.');

      expect(selectable('Správně je **I have been working** od rána.'),
          ['I', 'have', 'been', 'working']);
      expect(tokens.map((t) => t.rawText), isNot(contains(contains('*'))));
      expect(tokens.where((t) => t.isBold).map((t) => t.rawText),
          ['I', 'have', 'been', 'working']);
    });

    test('English example in quotes inside a Czech sentence stays selectable', () {
      expect(selectable('Místo "I don\'t talking" řekneme „I don\'t speak“.'),
          ['I', "don't", 'talking', 'I', "don't", 'speak']);
    });

    test('a Czech sentence in quotes is plain text', () {
      expect(selectable('Přelož: „Včera jsem byl v kině.“'), isEmpty);
    });

    test('a Czech name does not turn an English sentence into Czech', () {
      expect(selectable('Hi Tomáš, how are you today?'), ['Hi', 'how', 'are', 'you', 'today']);
    });

    test('a colon separates a Czech lead-in from an English sentence', () {
      expect(selectable('Příklad: I have been working here.'),
          ['I', 'have', 'been', 'working', 'here']);
    });

    test('selectable words are numbered in order, other tokens get -1', () {
      final tokens = tokenizeTutorText('Řekni **good morning** a **good night**.');

      expect(tokens.where((t) => t.isSelectableWord).map((t) => t.wordIndex), [0, 1, 2, 3]);
      expect(tokens.where((t) => !t.isSelectableWord).map((t) => t.wordIndex).toSet(), {-1});
    });
  });
}
