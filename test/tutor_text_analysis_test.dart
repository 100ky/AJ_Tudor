import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/tutor_text_analysis.dart';

void main() {
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
    test('citace opravené věty není stagnace', () {
      const history = [
        'Pozor, v angličtině neříkáme was done. Zkus to zopakovat: The presentation went well.'
      ];
      expect(repeatedTurnSimilarity('The presentation went well. Can you say that?', history), isNull);
    });
  });
}
