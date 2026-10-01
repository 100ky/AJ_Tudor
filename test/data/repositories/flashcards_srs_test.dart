import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

void main() {
  group('ChatMessage & Smart Bubbles Model Tests', () {
    test('ChatMessage without corrections should have hasCorrections = false', () {
      final msg = ChatMessage('Hello world', isUser: true);
      expect(msg.hasCorrections, false);
      expect(msg.corrections, null);
    });

    test('ChatMessage with corrections should report hasCorrections = true', () {
      const correction = ChatMessageCorrection(
        userSaid: 'I go yesterday',
        correctForm: 'I went yesterday',
        explanation: 'Minulý čas od slovesa go je went.',
        errorType: 'grammar',
      );

      final msg = ChatMessage(
        'I go yesterday',
        isUser: true,
        corrections: const [correction],
        correctedSentence: 'I went yesterday',
      );

      expect(msg.hasCorrections, true);
      expect(msg.corrections?.length, 1);
      expect(msg.corrections?.first.correctForm, 'I went yesterday');
      expect(msg.correctedSentence, 'I went yesterday');
    });
  });

  group('SessionRepository Flashcards SRS Tests', () {
    late AppDatabase db;
    late SessionRepository repo;

    setUp(() {
      // Použijeme in-memory SQLite databázi pro testy
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = SessionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('addFlashcard, getDueFlashcards and reviewFlashcard SRS cycle', () async {
      final insertRes = await repo.addFlashcard(
        frontText: 'Jak se řekne: "Mám 25 let"?',
        backText: 'I am 25 years old.',
        explanation: 'Věk se v angličtině vyjadřuje slovesem být.',
        errorType: 'grammar',
        sourceSentence: 'I have 25 years.',
      );

      expect(insertRes.isSuccess, true);
      final flashcardId = insertRes.valueOrNull!;
      expect(flashcardId, greaterThan(0));

      final dueCards = await repo.getDueFlashcards();
      expect(dueCards.length, 1);
      expect(dueCards.first.frontText, 'Jak se řekne: "Mám 25 let"?');
      expect(dueCards.first.backText, 'I am 25 years old.');

      // Review s hodnocením 2 (Good)
      final reviewRes = await repo.reviewFlashcard(flashcardId: flashcardId, rating: 2);
      expect(reviewRes.isSuccess, true);

      final allCards = await repo.getAllFlashcards();
      expect(allCards.first.repetitionCount, 1);
      expect(allCards.first.intervalDays, greaterThanOrEqualTo(2));
      expect(allCards.first.masteryScore, greaterThan(0.0));
    });

    test('createFlashcardFromTranscript uses czechPrompt for frontText', () async {
      final res = await repo.createFlashcardFromTranscript(
        transcriptId: 1,
        czechPrompt: 'Mám 25 let',
        correctForm: 'I am 25 years old.',
        explanation: 'Sloveso to be.',
        errorType: 'grammar',
        userSaid: 'I have 25 years.',
      );

      expect(res.isSuccess, true);
      final cards = await repo.getAllFlashcards();
      expect(cards.first.frontText, 'Mám 25 let');
      expect(cards.first.backText, 'I am 25 years old.');
      expect(cards.first.sourceSentence, 'I have 25 years.');
    });

    test('getFlashcardStats computes aggregate mastery metrics correctly', () async {
      final initialStats = await repo.getFlashcardStats();
      expect(initialStats.totalCards, 0);
      expect(initialStats.masteredPercentage, 0);

      // Přidáme kartičku
      final cardRes = await repo.addFlashcard(
        frontText: 'Ahoj',
        backText: 'Hello',
        explanation: 'Pozdrav',
        errorType: 'vocabulary',
      );
      final cardId = cardRes.getOrThrow();

      final statsAfterAdd = await repo.getFlashcardStats();
      expect(statsAfterAdd.totalCards, 1);
      expect(statsAfterAdd.dueCards, 1);
      expect(statsAfterAdd.newCards, 1);
      expect(statsAfterAdd.masteredCards, 0);

      // Ohodnotíme kartičku jako Snadné (3) několikrát pro navýšení mastery
      await repo.reviewFlashcard(flashcardId: cardId, rating: 3); // mastery +0.25 = 0.25
      await repo.reviewFlashcard(flashcardId: cardId, rating: 3); // 0.50
      await repo.reviewFlashcard(flashcardId: cardId, rating: 3); // 0.75
      await repo.reviewFlashcard(flashcardId: cardId, rating: 3); // 1.0 -> mastered!

      final statsAfterMastery = await repo.getFlashcardStats();
      expect(statsAfterMastery.masteredCards, 1);
      expect(statsAfterMastery.masteredPercentage, 100);
      expect(statsAfterMastery.newCards, 0);
    });

    test('rating card as Easy (3) immediately marks it as mastered', () async {
      final cardRes = await repo.addFlashcard(
        frontText: 'Kočka',
        backText: 'Cat',
        explanation: 'Zvíře',
        errorType: 'vocabulary',
      );
      final cardId = cardRes.getOrThrow();

      // Po jednom hodnocení "Snadné" se karta okamžitě započítá do zvládnutých
      await repo.reviewFlashcard(flashcardId: cardId, rating: 3);

      final stats = await repo.getFlashcardStats();
      expect(stats.masteredCards, 1);
      expect(stats.masteredPercentage, 100);
    });

    test('autoMigrateLegacyCardsToCzech translates legacy English questions to Czech', () async {
      // Vložíme starou kartičku s chybnou angličtinou na líci
      await repo.addFlashcard(
        frontText: 'Jak opravit / říct: "I have 25 years"?',
        backText: 'I am 25 years old.',
        explanation: 'Věk se váže se slovesem to be.',
        errorType: 'grammar',
        sourceSentence: 'I have 25 years.',
      );

      final fakeClient = _FakeGeminiBatchClient((prompt) {
        return 'Je mi 25 let';
      });

      final migratedCount = await repo.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(migratedCount, 1);

      final cards = await repo.getAllFlashcards();
      expect(cards.first.frontText, 'Je mi 25 let');
    });

    test('generateRandomVocabularyCards generates vocabulary flashcards tailored to student', () async {
      final fakeClient = _FakeGeminiBatchClient((prompt) {
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

      final result = await repo.generateRandomVocabularyCards(
        geminiClient: fakeClient,
        count: 2,
      );

      expect(result.isSuccess, true);
      expect(result.valueOrNull, 2);

      final cards = await repo.getAllFlashcards();
      expect(cards.length, 2);
      expect(cards.any((c) => c.backText == 'look forward to' && c.frontText == 'těšit se na'), true);
      expect(cards.any((c) => c.backText == 'perseverance' && c.frontText == 'vytrvalost'), true);
    });

    test('autoMigrateLegacyCardsToCzech handles batch JSON translation', () async {
      await repo.addFlashcard(
        frontText: 'Jak správně říct: "I have hunger"?',
        backText: 'I am hungry.',
        explanation: 'Hlad se vyjadřuje přídavným jménem hungry.',
        errorType: 'grammar',
        sourceSentence: 'I have hunger.',
      );

      final fakeClient = _FakeGeminiBatchClient((prompt) {
        return '[{"id": 1, "czechPrompt": "Mám hlad"}]';
      });

      final count = await repo.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(count, 1);

      final cards = await repo.getAllFlashcards();
      expect(cards.first.frontText, 'Mám hlad');
    });

    test('insertScenario inserts custom scenario into database without wiping existing', () async {
      final scenario = await repo.insertScenario(
        title: 'Pohovor v IT firmě',
        description: 'Role-play technického pohovoru.',
        tutorInstruction: 'Act as a friendly interviewer asking about Flutter.',
        difficulty: 'hard',
      );

      expect(scenario.id, greaterThan(0));
      expect(scenario.title, 'Pohovor v IT firmě');
      expect(scenario.difficulty, 'hard');

      final available = await repo.watchAvailableScenarios().first;
      expect(available.any((s) => s.id == scenario.id), true);
    });

    test('extractCzechFromExplanation extracts Czech phrase from explanation parentheses', () {
      expect(
        SessionRepository.extractCzechFromExplanation("Místo 'one months' má být 'one month' (jeden měsíc)."),
        'jeden měsíc',
      );
      expect(
        SessionRepository.extractCzechFromExplanation("Správný výraz: look forward to (těšit se na)"),
        'těšit se na',
      );
      expect(
        SessionRepository.extractCzechFromExplanation("Minulý čas slovesa (noun)"),
        null,
      );
    });

    test('isLegacyOrEnglishFront detects English or legacy templates', () {
      expect(SessionRepository.isLegacyOrEnglishFront('Jak říct: "one months"'), true);
      expect(SessionRepository.isLegacyOrEnglishFront('Jak opravit / říct: "one months"?'), true);
      expect(SessionRepository.isLegacyOrEnglishFront('Přeložte: "one month"'), true);
      expect(SessionRepository.isLegacyOrEnglishFront('Přeložte do angličtiny správné vyjádření'), true);
      expect(SessionRepository.isLegacyOrEnglishFront('one month', backText: 'one month'), true);
      
      // Čistá čeština nesmí být označena jako legacy
      expect(SessionRepository.isLegacyOrEnglishFront('jeden měsíc', backText: 'one month'), false);
      expect(SessionRepository.isLegacyOrEnglishFront('těšit se na', backText: 'look forward to'), false);
    });

    test('autoMigrateLegacyCardsToCzech converts "Jak říct: one months" to Czech', () async {
      await repo.addFlashcard(
        frontText: 'Jak říct: "one months"',
        backText: 'one month',
        explanation: 'Použijte jednotné číslo (jeden měsíc).',
        errorType: 'grammar',
        sourceSentence: 'I stayed there for one months.',
      );

      final fakeClient = _FakeGeminiBatchClient((prompt) {
        return 'jeden měsíc';
      });

      final count = await repo.autoMigrateLegacyCardsToCzech(fakeClient);
      expect(count, 1);

      final cards = await repo.getAllFlashcards();
      expect(cards.first.frontText, 'jeden měsíc');
      expect(cards.first.backText, 'one month');
    });

    test('createFlashcardFromTranscript falls back to explanation extraction instead of English', () async {
      final res = await repo.createFlashcardFromTranscript(
        transcriptId: 10,
        userSaid: 'for one months',
        correctForm: 'for one month',
        explanation: 'Jednotné číslo (na jeden měsíc).',
      );

      expect(res.isSuccess, true);
      final cards = await repo.getAllFlashcards();
      expect(cards.first.frontText, 'na jeden měsíc');
      expect(cards.first.backText, 'for one month');
    });

    test('reviewFlashcard calculates exact masteryScore progression for all 4 ratings', () async {
      final insertRes = await repo.addFlashcard(
        frontText: 'Testovací slovo',
        backText: 'Test word',
        explanation: 'Test',
        errorType: 'vocabulary',
      );
      final id = insertRes.getOrThrow();

      // Počáteční stav: mastery = 0.0, repetition = 0, interval = 1
      var card = (await repo.getAllFlashcards()).first;
      expect(card.masteryScore, 0.0);
      expect(card.repetitionCount, 0);

      // 1. Rating 1 (Hard): mastery +0.10 -> 0.10, repetition 1
      await repo.reviewFlashcard(flashcardId: id, rating: 1);
      card = (await repo.getAllFlashcards()).first;
      expect(card.masteryScore, closeTo(0.10, 0.001));
      expect(card.repetitionCount, 1);

      // 2. Rating 2 (Good): mastery +0.25 -> 0.35, repetition 2
      await repo.reviewFlashcard(flashcardId: id, rating: 2);
      card = (await repo.getAllFlashcards()).first;
      expect(card.masteryScore, closeTo(0.35, 0.001));
      expect(card.repetitionCount, 2);

      // 3. Rating 0 (Again): mastery -0.20 -> 0.15, repetition reset to 0, interval 1
      await repo.reviewFlashcard(flashcardId: id, rating: 0);
      card = (await repo.getAllFlashcards()).first;
      expect(card.masteryScore, closeTo(0.15, 0.001));
      expect(card.repetitionCount, 0);
      expect(card.intervalDays, 1);

      // 4. Rating 3 (Easy): mastery jumps directly to >= 0.85 (mastered)
      await repo.reviewFlashcard(flashcardId: id, rating: 3);
      card = (await repo.getAllFlashcards()).first;
      expect(card.masteryScore, greaterThanOrEqualTo(0.85));
      expect(card.repetitionCount, 1);
    });

    test('watchFlashcardStats emits reactive updates without heavy column projection', () async {
      // Stream by měl reagovat na přidání i na review
      final statsStream = repo.watchFlashcardStats();

      final initial = await statsStream.first;
      expect(initial.totalCards, 0);

      final insertRes = await repo.addFlashcard(
        frontText: 'Jablko',
        backText: 'Apple',
        explanation: 'Ovoce',
        errorType: 'vocabulary',
      );
      final id = insertRes.getOrThrow();

      final statsAfterAdd = await repo.getFlashcardStats();
      expect(statsAfterAdd.totalCards, 1);
      expect(statsAfterAdd.newCards, 1);
      expect(statsAfterAdd.masteredCards, 0);

      // Ohodnotíme jako Snadné
      await repo.reviewFlashcard(flashcardId: id, rating: 3);

      final statsAfterReview = await repo.getFlashcardStats();
      expect(statsAfterReview.totalCards, 1);
      expect(statsAfterReview.newCards, 0);
      expect(statsAfterReview.masteredCards, 1);
      expect(statsAfterReview.masteredPercentage, 100);
    });
  });
}

class _FakeGeminiBatchClient extends GeminiBatchClient {
  final String Function(String prompt) onSendMessage;
  _FakeGeminiBatchClient(this.onSendMessage) : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) async {
    return onSendMessage(text);
  }
}

