import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';

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
  });
}
