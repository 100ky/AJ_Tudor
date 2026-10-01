import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/features/flashcards/card_front_resolver.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class _PendingBatchClient extends GeminiBatchClient {
  final reply = Completer<String>();
  int calls = 0;
  _PendingBatchClient() : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) {
    calls++;
    return reply.future;
  }
}

Flashcard card({
  required String front,
  String back = 'one month',
  String explanation = '',
}) {
  final now = DateTime(2026, 10, 1);
  return Flashcard(
    id: 7,
    frontText: front,
    backText: back,
    explanation: explanation,
    errorType: 'grammar',
    intervalDays: 1,
    repetitionCount: 0,
    masteryScore: 0.0,
    nextReviewAt: now,
    createdAt: now,
  );
}

void main() {
  late List<(int, String)> saved;
  late int translatedCalls;

  CardFrontResolver resolver({GeminiBatchClient? gemini}) {
    return CardFrontResolver(
      saveFront: (id, text) => saved.add((id, text)),
      geminiClient: () => gemini,
      onTranslated: () => translatedCalls++,
    );
  }

  setUp(() {
    saved = [];
    translatedCalls = 0;
  });

  group('CardFrontResolver', () {
    test('a clean Czech front is shown as is', () {
      expect(resolver().resolve(card(front: 'jeden měsíc')), 'jeden měsíc');
      expect(saved, isEmpty);
    });

    test('a legacy front uses the Czech phrase from the explanation and saves it once', () {
      final r = resolver();
      final legacy = card(front: 'Jak říct: "one months"', explanation: 'Jednotné číslo (jeden měsíc).');

      expect(r.resolve(legacy), 'jeden měsíc');
      expect(r.resolve(legacy), 'jeden měsíc');
      expect(saved, [(7, 'jeden měsíc')]);
    });

    test('without a Gemini client a legacy front falls back to the raw text', () {
      expect(resolver().resolve(card(front: 'Přeložte do angličtiny')), 'Přeložte do angličtiny');
    });

    test('a legacy front is translated in the background exactly once', () async {
      final gemini = _PendingBatchClient();
      final r = resolver(gemini: gemini);
      final legacy = card(front: 'Přeložte do angličtiny');

      expect(r.resolve(legacy), CardFrontResolver.translatingPlaceholder);
      expect(r.resolve(legacy), CardFrontResolver.translatingPlaceholder);
      expect(gemini.calls, 1);

      gemini.reply.complete('"jeden měsíc"');
      await pumpEventQueue();

      expect(translatedCalls, 1);
      expect(saved, [(7, 'jeden měsíc')]);
      expect(r.resolve(legacy), 'jeden měsíc');
    });

    test('a failed translation keeps the placeholder and allows a retry', () async {
      final gemini = _PendingBatchClient();
      final r = resolver(gemini: gemini);
      final legacy = card(front: 'Přeložte do angličtiny');

      r.resolve(legacy);
      gemini.reply.completeError(Exception('offline'));
      await pumpEventQueue();

      expect(translatedCalls, 0);
      expect(saved, isEmpty);
      expect(r.resolve(legacy), CardFrontResolver.translatingPlaceholder);
      expect(gemini.calls, 2);
    });
  });
}
