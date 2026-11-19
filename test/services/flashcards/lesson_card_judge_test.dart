import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:aj_tudor/services/flashcards/lesson_card_judge.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_rest_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements GeminiBatchClient {}

class _MockRestCore extends Mock implements GeminiRestCore {}

void main() {
  final relax = ConversationCard(id: 36, czech: 'neodpočíval', english: "didn't relax");
  final boat = ConversationCard(id: 37, czech: 'zazimoval', english: 'winterized');
  late _MockClient client;

  setUp(() => client = _MockClient());

  void answer(String json) => when(() => client.sendMessage(
        any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'),
      )).thenAnswer((_) async => json);

  test('the card the model names is completed, an unknown or zero id is not', () async {
    final judge = LessonCardJudge(client);
    answer('{"cardId": 36, "reason": "Řekl to vlastními slovy."}');
    expect(
      (await judge.judge(remaining: [relax, boat], recentTutorLines: const [], studentText: 'I had no time to rest.'))?.id,
      36,
    );

    answer('{"cardId": 99, "reason": "?"}');
    expect(await judge.judge(remaining: [relax, boat], recentTutorLines: const [], studentText: 'Hmm.'), isNull);
    answer('{"cardId": 0, "reason": "Nic"}');
    expect(await judge.judge(remaining: [relax], recentTutorLines: const [], studentText: 'Hmm.'), isNull);
  });

  test('without a key, a reply or cards nothing is asked, a failure only skips the judgement', () async {
    expect(await LessonCardJudge(null).judge(remaining: [relax], recentTutorLines: const [], studentText: 'Hi'), isNull);
    final judge = LessonCardJudge(client);
    expect(await judge.judge(remaining: const [], recentTutorLines: const [], studentText: 'Hi'), isNull);
    expect(await judge.judge(remaining: [relax], recentTutorLines: const [], studentText: ' '), isNull);
    verifyNever(() => client.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')));

    when(() => client.sendMessage(any(),
            systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')))
        .thenThrow(Exception('503'));
    expect(await judge.judge(remaining: [relax], recentTutorLines: const [], studentText: 'I rested.'), isNull);
  });

  test('uses Decisions API primarily when decisionApi and apiKey are set', () async {
    final rest = _MockRestCore();
    final judge = LessonCardJudge(client, apiKey: 'test-key', decisionApi: rest);

    when(() => rest.createDecision(
          apiKey: 'test-key',
          body: any(named: 'body'),
        )).thenAnswer((_) async => {
          'answers': {
            'card': {'choice': 'card_36', 'confidence': 0.94},
          },
        });

    final matched = await judge.judge(
      remaining: [relax, boat],
      recentTutorLines: const [],
      studentText: 'I had no time to rest at all.',
    );
    expect(matched?.id, 36);
    verifyNever(() => client.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')));

    when(() => rest.createDecision(
          apiKey: 'test-key',
          body: any(named: 'body'),
        )).thenAnswer((_) async => {
          'answers': {
            'card': {'choice': 'none', 'confidence': 0.88},
          },
        });
    expect(
      await judge.judge(remaining: [relax, boat], recentTutorLines: const [], studentText: 'The weather was nice.'),
      isNull,
    );
  });

  test('falls back to GeminiBatchClient when Decisions API throws', () async {
    final rest = _MockRestCore();
    final judge = LessonCardJudge(client, apiKey: 'test-key', decisionApi: rest);

    when(() => rest.createDecision(
          apiKey: 'test-key',
          body: any(named: 'body'),
        )).thenThrow(Exception('429'));
    answer('{"cardId": 37, "reason": "Použil správný výraz."}');

    final matched = await judge.judge(
      remaining: [relax, boat],
      recentTutorLines: const [],
      studentText: 'We winterized the cabin in October.',
    );
    expect(matched?.id, 37);
    verify(() => client.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema'))).called(1);
  });
}
