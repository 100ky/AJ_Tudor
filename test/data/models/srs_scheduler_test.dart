import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/models/srs_scheduler.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12);

  SrsUpdate review(int rating, {int interval = 4, int repetitions = 2, double mastery = 0.5}) {
    return SrsScheduler.review(
      intervalDays: interval,
      repetitionCount: repetitions,
      masteryScore: mastery,
      rating: rating,
      now: now,
    );
  }

  group('SrsScheduler.review', () {
    test('Again (0) resets the interval and repetitions and lowers mastery', () {
      final u = review(0);
      expect(u.intervalDays, 1);
      expect(u.repetitionCount, 0);
      expect(u.masteryScore, closeTo(0.3, 1e-9));
      expect(u.nextReviewAt, now.add(const Duration(days: 1)));
    });

    test('Hard (1) grows the interval 1.2x and adds 0.10 mastery', () {
      final u = review(1);
      expect(u.intervalDays, 5); // ceil(4 * 1.2)
      expect(u.repetitionCount, 3);
      expect(u.masteryScore, closeTo(0.6, 1e-9));
      expect(u.nextReviewAt, now.add(const Duration(days: 5)));
    });

    test('Good (2) doubles the interval and adds 0.25 mastery', () {
      final u = review(2);
      expect(u.intervalDays, 8);
      expect(u.repetitionCount, 3);
      expect(u.masteryScore, closeTo(0.75, 1e-9));
    });

    test('Easy (3) triples the interval and marks the card as mastered', () {
      final u = review(3, mastery: 0.1);
      expect(u.intervalDays, 12);
      expect(u.repetitionCount, 3);
      expect(u.masteryScore, 0.85);
    });

    test('Easy (3) on an already mastered card keeps growing up to 1.0', () {
      expect(review(3, mastery: 0.8).masteryScore, closeTo(1.0, 1e-9)); // 0.8 + 0.25 -> 1.0, + 0.15 -> 1.0
      expect(review(3, mastery: 0.7).masteryScore, closeTo(1.0, 1e-9)); // 0.95 + 0.15 -> 1.0
    });

    test('intervals respect their minimum and maximum bounds', () {
      expect(review(1, interval: 1).intervalDays, 2); // ceil(1.2)
      expect(review(1, interval: 100).intervalDays, 60);
      expect(review(2, interval: 0).intervalDays, 2);
      expect(review(2, interval: 80).intervalDays, 90);
      expect(review(3, interval: 1).intervalDays, 4);
      expect(review(3, interval: 100).intervalDays, 180);
    });

    test('mastery never leaves the 0.0–1.0 range', () {
      expect(review(0, mastery: 0.1).masteryScore, 0.0);
      expect(review(2, mastery: 0.95).masteryScore, 1.0);
    });

    test('unknown rating only reschedules the card', () {
      final u = review(7);
      expect(u.intervalDays, 4);
      expect(u.repetitionCount, 2);
      expect(u.masteryScore, 0.5);
      expect(u.nextReviewAt, now.add(const Duration(days: 4)));
    });
  });
}
