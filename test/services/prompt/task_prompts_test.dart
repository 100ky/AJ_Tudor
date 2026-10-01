import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/prompt/task_prompts.dart';

void main() {
  group('TaskPrompts', () {
    test('translateToCzech quotes the English phrase', () {
      final prompt = TaskPrompts.translateToCzech('give up');
      expect(prompt, contains('"give up"'));
      expect(prompt, contains('VÝHRADNĚ čistý český překlad'));
    });

    test('extractTargetPhrase includes the sentence, student utterance and explanation', () {
      final prompt = TaskPrompts.extractTargetPhrase(
        correctForm: 'I need to clear my head.',
        userSaid: 'I need clean my head.',
        explanation: 'Ustálené spojení.',
      );
      expect(prompt, contains('Opravená věta: "I need to clear my head."'));
      expect(prompt, contains('Výrok studenta: "I need clean my head."'));
      expect(prompt, contains('Vysvětlení chyby: "Ustálené spojení."'));
      expect(prompt, contains('"target"'));
    });

    test('batchTranslateCardsToCzech embeds the cards as JSON', () {
      final cards = [
        {'id': 7, 'english': 'look forward to'},
      ];
      expect(TaskPrompts.batchTranslateCardsToCzech(cards), endsWith(jsonEncode(cards)));
    });

    test('randomVocabulary mentions interests and at most 40 known words', () {
      final known = List.generate(50, (i) => 'word$i');
      final prompt = TaskPrompts.randomVocabulary(
        count: 5,
        level: 'B2',
        interests: ['fotbal'],
        existingWords: known,
      );
      expect(prompt, contains('přesně 5'));
      expect(prompt, contains('úrovni B2'));
      expect(prompt, contains('fotbal'));
      expect(prompt, contains('word39'));
      expect(prompt, isNot(contains('word40')));
    });

    test('randomVocabulary omits empty optional sections', () {
      final prompt = TaskPrompts.randomVocabulary(
        count: 3,
        level: 'A2',
        interests: const [],
        existingWords: const [],
      );
      expect(prompt, isNot(contains('Témata a zájmy')));
      expect(prompt, isNot(contains('Vyhni se')));
    });

    test('wordTranslationRequest adds sentence context only when present', () {
      expect(
        TaskPrompts.wordTranslationRequest(word: 'run', contextSentence: '  I run daily. '),
        'Kontext věty: "I run daily."\nPřelož výraz: "run"',
      );
      expect(TaskPrompts.wordTranslationRequest(word: 'run'), 'Přelož výraz: "run"');
      expect(TaskPrompts.wordTranslationRequest(word: 'run', contextSentence: '  '),
          'Přelož výraz: "run"');
    });

    test('pronunciation prompts include the reference text and optional hint', () {
      final hint = TaskPrompts.spokenAnswerHint(
        promptContext: 'vzdát se',
        expectedEnglish: 'give up',
      );
      final system = TaskPrompts.pronunciationSystem(referenceText: 'give up', instructionHint: hint);
      expect(system, contains('Vzorový anglický text: "give up"'));
      expect(system, contains('se zadáním: "vzdát se"'));
      expect(TaskPrompts.pronunciationRequest('give up'), contains('"give up"'));
    });

    test('ttsTranscript puts the instruction before the transcript', () {
      final plain = TaskPrompts.ttsTranscript('Hello');
      expect(plain, startsWith('Read ONLY the transcript below with standard'));
      expect(plain, endsWith('#### TRANSCRIPT\nHello'));

      final styled = TaskPrompts.ttsTranscript('Hello', instruction: 'Speak slowly.');
      expect(styled, startsWith('Speak slowly.\nRead ONLY'));
      expect(styled, endsWith('#### TRANSCRIPT\nHello'));
    });

    test('drillKickoff targets a topic or recurring errors', () {
      expect(TaskPrompts.drillKickoff('present perfect'), contains('"present perfect"'));
      expect(TaskPrompts.drillKickoff(), contains('opakující se chyby'));
      expect(TaskPrompts.drillKickoff(''), contains('opakující se chyby'));
    });

    test('sessionFollowUp includes topic, level, history and the new message', () {
      final prompt = TaskPrompts.sessionFollowUp(
        topic: 'Cestování',
        targetLevel: 'B1',
        conversationHistory: 'Student: Hi\nTudor: Hello!',
        message: 'How are you?',
      );
      expect(prompt, contains('(Cestování)'));
      expect(prompt, contains('Úroveň studenta: B1.'));
      expect(prompt, contains('Student: Hi\nTudor: Hello!'));
      expect(prompt, contains('Nová zpráva od studenta: "How are you?"'));
    });

    test('customScenarioSystem lists recurring errors only when there are some', () {
      final withErrors = TaskPrompts.customScenarioSystem(
        userHint: 'restaurace',
        targetLevel: 'B1',
        recurringErrors: '["členy"]',
      );
      expect(withErrors, contains('POPIS OD STUDENTA: "restaurace"'));
      expect(withErrors, contains('ČASTÉ CHYBY: ["členy"]'));

      for (final empty in [null, '', '[]']) {
        final prompt = TaskPrompts.customScenarioSystem(
          userHint: 'restaurace',
          targetLevel: 'B1',
          recurringErrors: empty,
        );
        expect(prompt, isNot(contains('ČASTÉ CHYBY')), reason: 'recurringErrors = $empty');
      }
    });
  });
}
