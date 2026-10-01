import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/features/flashcards/review_session.dart';

Flashcard card(int id) {
  final now = DateTime(2026, 10, 1);
  return Flashcard(
    id: id,
    frontText: 'Zadání $id',
    backText: 'Answer $id',
    explanation: '',
    errorType: 'vocabulary',
    intervalDays: 1,
    repetitionCount: 0,
    masteryScore: 0.0,
    nextReviewAt: now,
    createdAt: now,
  );
}

void main() {
  group('ReviewSession', () {
    test('a session without due cards is empty and finished', () {
      final session = ReviewSession(const []);
      expect(session.isEmpty, true);
      expect(session.isFinished, true);
    });

    test('keeps a stable copy of the due cards', () {
      final due = [card(1), card(2)];
      final session = ReviewSession(due);
      due.clear();

      expect(session.total, 2);
      expect(session.current.id, 1);
      expect(session.isFinished, false);
    });

    test('Good and Easy count as mastered and advance', () {
      final session = ReviewSession([card(1), card(2)]);

      session.recordAnswer(session.current, 2);
      expect(session.index, 1);
      expect(session.current.id, 2);
      session.recordAnswer(session.current, 3);

      expect(session.masteredCount, 2);
      expect(session.againCount, 0);
      expect(session.isFinished, true);
    });

    test('Hard advances without counting as mastered', () {
      final session = ReviewSession([card(1)]);
      session.recordAnswer(session.current, 1);
      expect(session.masteredCount, 0);
      expect(session.againCount, 0);
      expect(session.isFinished, true);
    });

    test('Again moves the card to the end of the queue', () {
      final first = card(1);
      final session = ReviewSession([first, card(2)]);

      session.recordAnswer(first, 0);

      expect(session.againCount, 1);
      expect(session.total, 3);
      expect(session.current.id, 2);
      session.recordAnswer(session.current, 2);
      expect(session.current.id, 1);
      session.recordAnswer(session.current, 2);
      expect(session.isFinished, true);
      expect(session.masteredCount, 2);
    });

    test('removing the current card shows the next one', () {
      final session = ReviewSession([card(1), card(2)]);
      session.remove(1);
      expect(session.total, 1);
      expect(session.current.id, 2);
      expect(session.isFinished, false);
    });

    test('removing the last remaining card finishes the session', () {
      final session = ReviewSession([card(1)]);
      session.remove(1);
      expect(session.isFinished, true);
    });
  });
}
