import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/flashcard_repository.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/flashcards/flashcard_generation_service.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/prompt/task_prompts.dart';

class _FakeBatchClient extends GeminiBatchClient {
  final String Function(String prompt) handler;
  _FakeBatchClient(this.handler) : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) async {
    return handler(text);
  }
}

void main() {
  late AppDatabase db;
  late SessionRepository sessionRepo;
  late FlashcardRepository flashcardRepo;
  late ProfileRepository profileRepo;
  late FlashcardGenerationService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sessionRepo = SessionRepository(db);
    flashcardRepo = FlashcardRepository(db);
    profileRepo = ProfileRepository(db);
    service = FlashcardGenerationService(sessionRepo, flashcardRepo, profileRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('FlashcardGenerationService - cards from errors', () {
    test('generateFlashcardsFromErrors generates cards and filters out invalid sentences', () async {
      final s = (await sessionRepo.startNewSession()).getOrThrow();

      // Valid error
      await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'She do not like tea',
        correctForm: 'She does not like tea',
        explanation: '3. os. jednotného čísla (nemá ráda čaj)',
      );

      // Filtered out: userSaid == correctForm
      await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'Identical sentence',
        correctForm: 'Identical sentence',
        explanation: 'Not an error',
      );

      // Filtered out: tutor monologue / AI phrase
      await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'Wait a minute, as an AI tutor I think...',
        correctForm: 'Wait a minute...',
        explanation: 'Irrelevant',
      );

      final client = _FakeBatchClient((prompt) => 'Ona nemá ráda čaj');
      final genRes = await service.generateFlashcardsFromErrors(
        sessionId: s,
        limit: 10,
        geminiClient: client,
      );

      expect(genRes.isSuccess, true);
      expect(genRes.getOrThrow(), 1);

      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.length, 1);
      expect(cards.first.backText, 'She does not like tea');
      expect(cards.first.frontText, 'Ona nemá ráda čaj');

      // Error logs should now be marked as inFlashcard = true
      final logs = await sessionRepo.getErrorLogs(s);
      expect(logs.every((l) => l.inFlashcard), true);
    });

    test('generateFlashcardsFromErrors distills atomic target word/phrase from sentence', () async {
      final s = (await sessionRepo.startNewSession()).getOrThrow();

      await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'vocabulary',
        userSaid: 'Running cleans my head',
        correctForm: 'Running clears my head regularly',
        explanation: 'Idiom clear one\'s head',
      );

      final client = _FakeBatchClient((prompt) {
        if (prompt.contains('extrahuj VÝHRADNĚ cílové anglické slovíčko')) {
          return '{"target": "clear one\'s head", "czech": "vyčistit si hlavu"}';
        }
        return 'vyčistit si hlavu';
      });

      final genRes = await service.generateFlashcardsFromErrors(
        sessionId: s,
        geminiClient: client,
      );

      expect(genRes.isSuccess, true);
      expect(genRes.getOrThrow(), 1);

      final cards = await flashcardRepo.getAllFlashcards();
      final card = cards.firstWhere((c) => c.backText == 'clear one\'s head');
      expect(card.frontText, 'vyčistit si hlavu');
      expect(card.sourceSentence, 'Running clears my head regularly');
    });
  });

  group('FlashcardGenerationService - legacy migration & vocabulary', () {
    test('autoMigrateLegacyCardsToCzech translates legacy English questions to Czech', () async {
      // Vložíme starou kartičku s chybnou angličtinou na líci
      await flashcardRepo.addFlashcard(
        frontText: 'Jak opravit / říct: "I have 25 years"?',
        backText: 'I am 25 years old.',
        explanation: 'Věk se váže se slovesem to be.',
        errorType: 'grammar',
        sourceSentence: 'I have 25 years.',
      );

      final fakeClient = _FakeBatchClient((prompt) {
        return 'Je mi 25 let';
      });

      final migratedCount = await service.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(migratedCount, 1);

      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.first.frontText, 'Je mi 25 let');
    });

    test('autoMigrateLegacyCardsToCzech handles batch JSON translation', () async {
      await flashcardRepo.addFlashcard(
        frontText: 'Jak správně říct: "I have hunger"?',
        backText: 'I am hungry.',
        explanation: 'Hlad se vyjadřuje přídavným jménem hungry.',
        errorType: 'grammar',
        sourceSentence: 'I have hunger.',
      );

      final fakeClient = _FakeBatchClient((prompt) {
        return '[{"id": 1, "czechPrompt": "Mám hlad"}]';
      });

      final count = await service.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(count, 1);

      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.first.frontText, 'Mám hlad');
    });

    test('autoMigrateLegacyCardsToCzech converts "Jak říct: one months" to Czech', () async {
      await flashcardRepo.addFlashcard(
        frontText: 'Jak říct: "one months"',
        backText: 'one month',
        explanation: 'Použijte jednotné číslo (jeden měsíc).',
        errorType: 'grammar',
        sourceSentence: 'I stayed there for one months.',
      );

      final fakeClient = _FakeBatchClient((prompt) {
        return 'jeden měsíc';
      });

      final count = await service.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(count, 1);

      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.first.frontText, 'jeden měsíc');
      expect(cards.first.backText, 'one month');
    });

    test('generateRandomVocabularyCards generates vocabulary flashcards tailored to student', () async {
      final fakeClient = _FakeBatchClient((prompt) {
        return '''
[
  {
    "czech": "těšit se na",
    "english": "look forward to",
    "exampleSentence": "I look forward to seeing you. (Těším se na setkání s tebou.)"
  },
  {
    "czech": "vytrvalost",
    "english": "perseverance",
    "exampleSentence": "Success requires perseverance. (Úspěch vyžaduje vytrvalost.)"
  }
]
''';
      });

      final result = await service.generateRandomVocabularyCards(
        geminiClient: fakeClient,
        count: 2,
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, 2);

      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.length, 2);
      expect(cards.any((c) => c.backText == 'look forward to' && c.frontText == 'těšit se na'), true);
      expect(cards.any((c) => c.backText == 'perseverance' && c.frontText == 'vytrvalost'), true);
    });
  });

  group('FlashcardGenerationService.translateToCzech', () {
    test('translateToCzech cleans quotes and line breaks from the model output', () async {
      final client = _FakeBatchClient((prompt) => '  "Těším se\nna to"  ');
      expect(await FlashcardGenerationService.translateToCzech(client, 'look forward to'), 'Těším se na to');
    });

    test('translateToCzech returns null for empty or error output', () async {
      expect(await FlashcardGenerationService.translateToCzech(_FakeBatchClient((_) => '  '), 'x'), isNull);
      expect(
        await FlashcardGenerationService.translateToCzech(_FakeBatchClient((_) => '❌ Chyba AI'), 'x'),
        isNull,
      );
    });

    test('translateToCzech sends the shared translation prompt', () async {
      String? sent;
      await FlashcardGenerationService.translateToCzech(
        _FakeBatchClient((prompt) {
          sent = prompt;
          return 'vzdát se';
        }),
        'give up',
      );
      expect(sent, TaskPrompts.translateToCzech('give up'));
    });
  });
}
