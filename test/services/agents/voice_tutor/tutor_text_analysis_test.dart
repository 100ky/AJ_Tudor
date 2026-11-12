import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/tutor_text_analysis.dart';

void main() {
  group('stripCjkCharacters', () {
    test('removes hallucinated Asian characters and keeps the rest', () {
      expect(stripCjkCharacters('응'), '');
      expect(stripCjkCharacters('I am fine 응'), 'I am fine ');
      expect(stripCjkCharacters('Dobrý den'), 'Dobrý den');
    });
  });

  group('hasSpokenWords', () {
    test('a turn transcribed only as dots has no words', () {
      expect(hasSpokenWords('...'), isFalse);
      expect(hasSpokenWords(' … '), isFalse);
      expect(hasSpokenWords(''), isFalse);
    });

    test('real speech in English or Czech has words', () {
      expect(hasSpokenWords('Take your time...'), isTrue);
      expect(hasSpokenWords('To je v pořádku.'), isTrue);
    });
  });

  group('meaningfulWordCount', () {
    test('counts words longer than one character', () {
      expect(meaningfulWordCount('I like it, really!'), 3);
    });

    test('ignores answers made only of fillers', () {
      expect(meaningfulWordCount('Um... uh, hmm'), isNull);
    });

    test('fillers mixed with words still count', () {
      expect(meaningfulWordCount('um maybe tomorrow'), 3);
    });

    test('punctuation only counts as an empty (short) answer', () {
      expect(meaningfulWordCount('...'), 0);
    });
  });

  group('removeIntraTurnRepetition', () {
    test('drops a sentence the model repeated', () {
      expect(
        removeIntraTurnRepetition('How are you? I am fine. How are you?'),
        'How are you? I am fine.',
      );
    });

    test('drops a truncated copy of an earlier sentence', () {
      expect(
        removeIntraTurnRepetition('That sounds really great! That sounds really'),
        'That sounds really great!',
      );
    });

    test('keeps short repeated fragments and distinct sentences', () {
      expect(removeIntraTurnRepetition('Yes. No. Yes!'), 'Yes. No. Yes!');
      expect(removeIntraTurnRepetition(''), '');
    });
  });

  group('extractRepeatTarget', () {
    test('vytáhne větu v uvozovkách za výzvou', () {
      expect(
        extractRepeatTarget(
            'Pozor, neříkáme "on my demo didn\'t happen". Lepší je říct: "We didn\'t get to my demo because they were busy." Zkus to zopakovat: "We didn\'t get to my demo."'),
        "We didn't get to my demo.",
      );
    });

    test('vytáhne větu bez uvozovek', () {
      expect(
        extractRepeatTarget('Bylo to dobré. Zkus to zopakovat: The presentation went well.'),
        'The presentation went well.',
      );
      expect(extractRepeatTarget('Zkus to říct: It pissed me off!'), 'It pissed me off!');
    });

    test('bez výzvy nebo s češtinou vrátí null', () {
      expect(extractRepeatTarget('Spot on! And how was the audience reaction?'), isNull);
      expect(extractRepeatTarget('Zkus to říct: Mám to za sebou'), isNull);
      expect(extractRepeatTarget('Zkus to!'), isNull);
    });
  });

  group('repeatedTurnSimilarity', () {
    test('no history or no significant words means no repetition', () {
      expect(repeatedTurnSimilarity('What did you cook today?', const []), isNull);
      expect(repeatedTurnSimilarity('Ok. Yes.', ['Ok. Yes.']), isNull);
    });

    test('detects a turn that reuses most significant words', () {
      final similarity = repeatedTurnSimilarity(
        'What kind of music do you listen to these days?',
        ['Tell me, what kind of music do you listen to?'],
      );
      expect(similarity, isNotNull);
      expect(similarity!, greaterThan(0.45));
    });

    test('detects a copied opening even with low word overlap', () {
      // Jaccard 4/11 ≈ 0.36 is below the limit, but the first 40 characters repeat
      final similarity = repeatedTurnSimilarity(
        'That reminds me of something you told me last week about your job',
        ['Earlier: that reminds me of something you told me yesterday, right?'],
      );
      expect(similarity, closeTo(4 / 11, 1e-9));
    });

    test('a short copied opening (under 40 characters) is not repetition', () {
      // Jaccard 3/7 ≈ 0.43, only the first 28 characters repeat
      expect(
        repeatedTurnSimilarity(
          'That reminds me of something completely different',
          ['Earlier: that reminds me of something we discussed'],
        ),
        isNull,
      );
    });

    test('citace opravené věty není stagnace', () {
      const history = [
        'Pozor, v angličtině neříkáme was done. Zkus to zopakovat: The presentation went well.'
      ];
      expect(repeatedTurnSimilarity('The presentation went well. Can you say that?', history), isNull);
    });

    test('unrelated turns are not repetition', () {
      expect(
        repeatedTurnSimilarity(
          'Have you ever travelled abroad by train?',
          ['What is your favourite breakfast?'],
        ),
        isNull,
      );
    });
  });
}
