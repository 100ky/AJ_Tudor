import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/flashcards/sentence_highlight.dart';

/// Podtrzene casti vety jako text.
List<String> marked(String sentence, String phrase) => [
      for (final r in highlightRanges(sentence, phrase)) sentence.substring(r.start, r.end),
    ];

void main() {
  group('highlightRanges', () {
    test('finds the whole phrase regardless of case', () {
      expect(marked('Pay attention to the road.', 'pay attention'), ['Pay attention']);
      expect(highlightRanges('Pay attention to the road.', 'pay attention'), [(start: 0, end: 13)]);
    });

    test('finds every occurrence of the phrase', () {
      expect(marked('Go on, go on!', 'go on'), ['Go on', 'go on']);
    });

    test('matches whole words only', () {
      expect(marked('Concatenate the strings.', 'cat'), isEmpty);
      expect(marked('The cars were scared.', 'care'), isEmpty);
    });

    test('recognizes common inflected forms', () {
      expect(marked('She is taking a break.', 'take'), ['taking']);
      expect(marked('He studied all night.', 'study'), ['studied']);
      expect(marked('I was running late.', 'run'), ['running']);
      expect(marked('She cared about it.', 'care'), ['cared']);
    });

    test('falls back to the words of a short phrase and skips tiny words', () {
      expect(marked('She takes good care of it.', 'take care of'), ['takes', 'care']);
    });

    test('accepts both apostrophe styles', () {
      expect(marked('I don’t know.', "don't"), ['don’t']);
    });

    test('a long phrase that is not in the sentence highlights nothing', () {
      expect(marked('I goes to school every day.', 'I go to school every day'), isEmpty);
    });

    test('empty input highlights nothing', () {
      expect(highlightRanges('', 'word'), isEmpty);
      expect(highlightRanges('Some sentence.', '  …  '), isEmpty);
    });
  });
}
