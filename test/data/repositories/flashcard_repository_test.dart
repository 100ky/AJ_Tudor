import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/flashcard_repository.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';

void main() {
  late AppDatabase db;
  late FlashcardRepository repo;
  late SessionRepository sessionRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FlashcardRepository(db);
    sessionRepo = SessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FlashcardRepository - Duplicates & bookkeeping', () {
    test('addFlashcard rejects duplicates with identical backText or errorLogId', () async {
      final s = (await sessionRepo.startNewSession()).getOrThrow();
      final errId = (await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'I go',
        correctForm: 'I went',
        explanation: 'Past tense',
      )).getOrThrow();

      final res1 = await repo.addFlashcard(
        frontText: 'Šel jsem',
        backText: 'I went',
        explanation: 'Past tense of go is went',
        errorLogId: errId,
      );
      expect(res1.isSuccess, true);
      final firstCardId = res1.getOrThrow();

      // Duplicate by errorLogId
      final res2 = await repo.addFlashcard(
        frontText: 'Different front',
        backText: 'Different back',
        explanation: 'Different explanation',
        errorLogId: errId,
      );
      expect(res2.isSuccess, true);
      expect(res2.getOrThrow(), firstCardId);

      // Duplicate by backText (case-insensitive)
      final res3 = await repo.addFlashcard(
        frontText: 'Jiný český překlad',
        backText: '  i went  ',
        explanation: 'Minulý čas',
      );
      expect(res3.isSuccess, true);
      expect(res3.getOrThrow(), firstCardId);

      // Total cards in database should still be 1
      final allCards = await repo.getAllFlashcards();
      expect(allCards.length, 1);
    });

    test('addFlashcard marks sourceSentence matching transcripts and error logs as inFlashcard', () async {
      final s = (await sessionRepo.startNewSession()).getOrThrow();
      await sessionRepo.addTranscript(
        sessionId: s,
        speaker: 'user',
        content: 'I have 20 years and I study math.',
      );
      final errId = (await sessionRepo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'I have 20 years',
        correctForm: 'I am 20 years old',
        explanation: 'Věk slovesem be',
      )).getOrThrow();

      await repo.addFlashcard(
        frontText: 'Je mi 20 let',
        backText: 'I am 20 years old',
        explanation: 'Věk se vyjadřuje pomocí to be',
        sourceSentence: 'I have 20 years',
        errorLogId: errId,
      );

      final transcripts = await sessionRepo.getTranscripts(s);
      expect(transcripts.first.inFlashcard, true);

      final errorLogs = await sessionRepo.getErrorLogs(s);
      expect(errorLogs.first.inFlashcard, true);
    });

    test('deleteFlashcard and updateFlashcardFrontText', () async {
      final res = await repo.addFlashcard(
        frontText: 'Původní text',
        backText: 'Original text',
        explanation: 'Vysvětlení',
      );
      final cardId = res.getOrThrow();

      await repo.updateFlashcardFrontText(cardId, 'Upravený český text');
      var card = (await repo.getAllFlashcards()).first;
      expect(card.frontText, 'Upravený český text');

      final delRes = await repo.deleteFlashcard(cardId);
      expect(delRes.isSuccess, true);
      expect(await repo.getAllFlashcards(), isEmpty);
    });

    test('removeDuplicateFlashcards keeps highest masteryScore card', () async {
      // Manually insert 3 cards with same backText but varying mastery
      final now = DateTime.now();
      await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 1',
          backText: 'Dog',
          explanation: 'Zvire',
          masteryScore: const Value(0.2),
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      final id2 = await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 2',
          backText: 'dog', // case-insensitive
          explanation: 'Zvire',
          masteryScore: const Value(0.9), // highest!
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 3',
          backText: 'DOG',
          explanation: 'Zvire',
          masteryScore: const Value(0.5),
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      final removedCount = await repo.removeDuplicateFlashcards();
      expect(removedCount, 2);

      final remaining = await repo.getAllFlashcards();
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
      expect(remaining.first.masteryScore, 0.9);
    });

    test('cleanupInvalidFlashcards deletes cards with tutor monologue leaks and oversized cards', () async {
      // 1. Valid card
      await repo.addFlashcard(
        frontText: 'vyčistit si hlavu',
        backText: 'clear one\'s head',
        explanation: 'Idiom',
      );

      // 2. Leaked tutor instruction card (like #266)
      await repo.addFlashcard(
        frontText: 'Zkus se prosím soustředit na naši anglickou konverzaci a nepřepínej do překládání úkolů.',
        backText: 'was at my father\'s house',
        explanation: 'Tutor prompt leak',
      );

      // 3. Oversized card
      await repo.addFlashcard(
        frontText: 'A' * 150,
        backText: 'B' * 150,
        explanation: 'Too long',
      );

      final initialCards = await repo.getAllFlashcards();
      expect(initialCards.length, 3);

      final deleted = await repo.cleanupInvalidFlashcards();
      expect(deleted, 2);

      final remaining = await repo.getAllFlashcards();
      expect(remaining.length, 1);
      expect(remaining.first.backText, 'clear one\'s head');
    });
  });

  group('FlashcardRepository - SRS & statistics', () {
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

  group('FlashcardRepository - card text heuristics', () {
    test('extractCzechFromExplanation extracts Czech phrase from explanation parentheses', () {
      expect(
        FlashcardRepository.extractCzechFromExplanation("Místo 'one months' má být 'one month' (jeden měsíc)."),
        'jeden měsíc',
      );
      expect(
        FlashcardRepository.extractCzechFromExplanation("Správný výraz: look forward to (těšit se na)"),
        'těšit se na',
      );
      expect(
        FlashcardRepository.extractCzechFromExplanation("Minulý čas slovesa (noun)"),
        null,
      );
    });

    test('isLegacyOrEnglishFront detects English or legacy templates', () {
      expect(FlashcardRepository.isLegacyOrEnglishFront('Jak říct: "one months"'), true);
      expect(FlashcardRepository.isLegacyOrEnglishFront('Jak opravit / říct: "one months"?'), true);
      expect(FlashcardRepository.isLegacyOrEnglishFront('Přeložte: "one month"'), true);
      expect(FlashcardRepository.isLegacyOrEnglishFront('Přeložte do angličtiny správné vyjádření'), true);
      expect(FlashcardRepository.isLegacyOrEnglishFront('one month', backText: 'one month'), true);
      
      // Čistá čeština nesmí být označena jako legacy
      expect(FlashcardRepository.isLegacyOrEnglishFront('jeden měsíc', backText: 'one month'), false);
      expect(FlashcardRepository.isLegacyOrEnglishFront('těšit se na', backText: 'look forward to'), false);
    });
  });
}
