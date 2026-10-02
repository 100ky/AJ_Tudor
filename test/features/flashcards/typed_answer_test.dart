import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/flashcards/typed_answer.dart';

void main() {
  group('TypedAnswer.evaluate', () {
    test('exact answer scores 1.0', () {
      expect(TypedAnswer.evaluate('escape', 'escape').score, 1.0);
    });

    test('ignores case, punctuation, extra spaces and curly apostrophes', () {
      final answer = TypedAnswer.evaluate('  Clear ONE’S   head! ', "clear one's head");
      expect(answer.score, 1.0);
      expect(answer.text, 'Clear ONE’S   head!');
    });

    test('ignores leading "to" of infinitives', () {
      expect(TypedAnswer.evaluate('to escape', 'escape').score, 1.0);
      expect(TypedAnswer.evaluate('escape', 'to escape').score, 1.0);
    });

    test('matches the best of variants separated by " / "', () {
      expect(TypedAnswer.evaluate('run away', 'escape / run away').score, 1.0);
    });

    test('partial answer scores in between', () {
      final score = TypedAnswer.evaluate('I am very hungry', 'I am really very hungry.').score;
      expect(score, greaterThan(0.65));
      expect(score, lessThan(0.85));
    });

    test('unrelated answer scores low', () {
      expect(TypedAnswer.evaluate('banana', 'clear one\'s head').score, lessThan(0.4));
    });

    test('answer without letters scores 0', () {
      expect(TypedAnswer.evaluate('???', 'escape').score, 0.0);
    });
  });
}
