import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/features/flashcards/card_explanation_resolver.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class _PendingBatchClient extends GeminiBatchClient {
  final reply = Completer<String>();
  final prompts = <String>[];
  _PendingBatchClient() : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) {
    prompts.add(text);
    return reply.future;
  }
}

Flashcard card({String explanation = '', String? sentence = 'You should pay attention to details.'}) {
  final now = DateTime(2026, 10, 1);
  return Flashcard(
    id: 3,
    frontText: 'dávat pozor',
    backText: 'pay attention',
    explanation: explanation,
    errorType: 'vocabulary',
    intervalDays: 1,
    repetitionCount: 0,
    masteryScore: 0.0,
    nextReviewAt: now,
    createdAt: now,
    sourceSentence: sentence,
  );
}

void main() {
  late List<(int, String)> saved;
  late int explainedCalls;

  CardExplanationResolver resolver({GeminiBatchClient? gemini}) {
    return CardExplanationResolver(
      saveExplanation: (id, text) => saved.add((id, text)),
      geminiClient: () => gemini,
      onExplained: () => explainedCalls++,
    );
  }

  setUp(() {
    saved = [];
    explainedCalls = 0;
  });

  group('CardExplanationResolver', () {
    test('recognizes placeholder explanations', () {
      expect(CardExplanationResolver.isPlaceholder(''), isTrue);
      expect(CardExplanationResolver.isPlaceholder('Z věty tutora: "You should pay attention."'), isTrue);
      expect(CardExplanationResolver.isPlaceholder('Slovíčko z konverzace s tutorem'), isTrue);
      expect(CardExplanationResolver.isPlaceholder('Oprava chyby z konverzace'), isTrue);
      expect(CardExplanationResolver.isPlaceholder('Minulý čas slovesa go je went.'), isFalse);
    });

    test('a real explanation is shown as is without asking Gemini', () {
      final gemini = _PendingBatchClient();
      expect(
        resolver(gemini: gemini).resolve(card(explanation: ' Minulý čas slovesa go je went. ')),
        'Minulý čas slovesa go je went.',
      );
      expect(gemini.prompts, isEmpty);
    });

    test('without a Gemini client a placeholder shows no explanation', () {
      expect(resolver().resolve(card(explanation: 'Z věty tutora: "..."')), isNull);
    });

    test('a placeholder is explained in the background exactly once and saved', () async {
      final gemini = _PendingBatchClient();
      final r = resolver(gemini: gemini);
      final legacy = card(explanation: 'Z věty tutora: "You should pay attention to details."');

      expect(r.resolve(legacy), CardExplanationResolver.loadingText);
      expect(r.resolve(legacy), CardExplanationResolver.loadingText);
      expect(gemini.prompts, hasLength(1));
      expect(gemini.prompts.single, contains('"pay attention"'));
      expect(gemini.prompts.single, contains('You should pay attention to details.'));

      gemini.reply.complete('**Pay attention** = věnovat pozornost; pojí se s předložkou *to*.');
      await pumpEventQueue();

      const explanation = 'Pay attention = věnovat pozornost; pojí se s předložkou to.';
      expect(explainedCalls, 1);
      expect(saved, [(3, explanation)]);
      expect(r.resolve(legacy), explanation);
    });

    test('a failed explanation hides the box and is not retried', () async {
      final gemini = _PendingBatchClient();
      final r = resolver(gemini: gemini);
      final legacy = card();

      r.resolve(legacy);
      gemini.reply.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(explainedCalls, 1);
      expect(saved, isEmpty);
      expect(r.resolve(legacy), isNull);
      expect(gemini.prompts, hasLength(1));
    });

    test('an empty model reply counts as a failure', () async {
      final gemini = _PendingBatchClient();
      final r = resolver(gemini: gemini);

      r.resolve(card(sentence: null));
      gemini.reply.complete('  ');
      await pumpEventQueue();

      expect(saved, isEmpty);
      expect(r.resolve(card(sentence: null)), isNull);
    });
  });
}
