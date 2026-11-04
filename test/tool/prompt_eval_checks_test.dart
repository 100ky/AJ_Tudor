import 'package:flutter_test/flutter_test.dart';

import '../../tool/prompt_eval/checks.dart';

List<String> failedChecks(CaseKind kind, String reply, {List<String> earlierTutorLines = const []}) =>
    checkReply(kind, reply, earlierTutorLines: earlierTutorLines, recentContext: reply)
        .where((c) => !c.passed)
        .map((c) => c.name)
        .toList();

void main() {
  group('test promptu tutora: automatické kontroly', () {
    test('oprava se zkouškou, bez otázky k tématu, projde', () {
      const reply = 'Pozor na čas. Neříkáme "I celebrate", ale "I am celebrating". Zkus to říct: "I am celebrating my birthday."';
      expect(failedChecks(CaseKind.correct, reply), isEmpty);
    });

    test('oprava s otázkou k tématu neprojde', () {
      const reply = 'Pozor, správně je "she doesn\'t". Zkus to říct! And what do you cook together?';
      expect(failedChecks(CaseKind.correct, reply), ['v tahu s opravou bez otázky k tématu']);
    });

    test('citovaná věta s otazníkem a „Can you say“ nejsou otázky k tématu', () {
      const reply = 'Great! For "kaše" we say mashed potatoes. Can you say: "My dad cooked mashed potatoes?"';
      expect(topicQuestions(reply), 0);
      expect(isCorrectionTurn(reply), isTrue);
    });

    test('oprava drobnosti tam, kde se čeká jen reakce, neprojde', () {
      const reply = 'Pozor na člen, říkáme "It was a normal speech." Zkus to zopakovat.';
      expect(failedChecks(CaseKind.noCorrection, reply), contains('bez výzvy k zopakování'));
    });

    test('reakce s jednou otázkou projde, se dvěma ne', () {
      expect(failedChecks(CaseKind.continueTopic, 'Spot on! What did your family enjoy most?'), isEmpty);
      expect(
        failedChecks(CaseKind.continueTopic, 'Spot on! Was it fun? Who came?'),
        containsAll(['nejvýš jedna otázka', 'právě jedna otázka k tématu']),
      );
    });

    test('„v angličtině neříkáme“ u české věty neprojde', () {
      const reply = 'Pozor, v angličtině neříkáme "přepsat", ale "copy". Zkus to říct: "She copies the data."';
      expect(failedChecks(CaseKind.translate, reply), ['bez „v angličtině neříkáme“']);
    });

    test('čekání musí být krátké a bez otázky, ticho stačí', () {
      expect(failedChecks(CaseKind.wait, 'Take your time...'), isEmpty);
      expect(failedChecks(CaseKind.wait, ''), isEmpty);
      expect(failedChecks(CaseKind.wait, 'No rush! So what did your dad prepare for the party?'), isNotEmpty);
    });

    test('odbočení k jídlu nebo koníčkům, o kterých řeč nebyla, se pozná', () {
      // Lekce 19: po české větě o projektu tutor uhnul k odpočinku a detektivkám
      const context = 'Do you ever get feedback from the users of your SaaS project?\nNikdo to zatím nechce.';
      expect(classicTopicDrift('How do you usually relax after work, maybe with a good detective show?', context),
          containsAll(['relax', 'detective']));
      expect(classicTopicDrift('Did you cook something special for the party?', context), ['cook']);
      // Když o jídle mluví student, téma smí pokračovat
      expect(classicTopicDrift('What did your dad cook?', 'My dad cooked garlic soup.'), isEmpty);
      expect(classicTopicDrift('Is anyone using your SaaS yet?', context), isEmpty);
    });

    test('znovu položená otázka se pozná, nová ne', () {
      const earlier = ['That sounds tasty! What is your favorite thing to grill when you have guests over?'];
      expect(repeatsEarlierQuestion('Great! What is your absolute favorite thing to grill?', earlier), isTrue);
      expect(repeatsEarlierQuestion('Nice! Which marinade do you use for pork neck?', earlier), isFalse);
      expect(
        failedChecks(CaseKind.stayOnTopic, 'Spot on! What is your favorite thing to grill?', earlierTutorLines: earlier),
        contains('neopakuje dřívější otázku'),
      );
    });

    test('u „Haló?“ smí tutor zopakovat svou otázku', () {
      const earlier = ['Spot on! And about your work, which projects are you programming tonight?'];
      expect(
        failedChecks(CaseKind.answer, "I'm here! Which projects are you programming tonight?", earlierTutorLines: earlier),
        isEmpty,
      );
    });

    test('prozrazený pokyn režiséra neprojde', () {
      expect(failedChecks(CaseKind.answer, '[DIRECTOR WHISPER] Ask about the party.'), ['neprozradí pokyny ani markdown']);
    });
  });
}
