/// Nový stav kartičky po hodnocení při opakování.
class SrsUpdate {
  final int intervalDays;
  final int repetitionCount;
  final double masteryScore;
  final DateTime nextReviewAt;

  const SrsUpdate({
    required this.intervalDays,
    required this.repetitionCount,
    required this.masteryScore,
    required this.nextReviewAt,
  });
}

/// Plánovač intervalového opakování kartiček (Spaced Repetition System).
abstract final class SrsScheduler {
  /// Spočítá nový interval, počet opakování a úroveň zvládnutí po hodnocení [rating]:
  /// - `0` (Znovu / Again): Reset intervalu na 1 den, mastery klesá.
  /// - `1` (Těžké / Hard): Interval se prodlouží 1.2x.
  /// - `2` (Dobré / Good): Interval se prodlouží 2.0x.
  /// - `3` (Snadné / Easy): Interval se prodlouží 3.0x, mastery roste.
  ///
  /// Jiná hodnota [rating] stav kartičky nemění, jen ji znovu naplánuje.
  static SrsUpdate review({
    required int intervalDays,
    required int repetitionCount,
    required double masteryScore,
    required int rating,
    DateTime? now,
  }) {
    int newRepetition = repetitionCount;
    int newInterval = intervalDays;
    double newMastery = masteryScore;

    switch (rating) {
      case 0: // Again
        newRepetition = 0;
        newInterval = 1;
        newMastery = (newMastery - 0.2).clamp(0.0, 1.0);
        break;
      case 1: // Hard
        newRepetition += 1;
        newInterval = (newInterval * 1.2).ceil().clamp(1, 60);
        newMastery = (newMastery + 0.10).clamp(0.0, 1.0);
        break;
      case 2: // Good
        newRepetition += 1;
        newInterval = (newInterval * 2.0).ceil().clamp(2, 90);
        newMastery = (newMastery + 0.25).clamp(0.0, 1.0);
        break;
      case 3: // Easy
        newRepetition += 1;
        newInterval = (newInterval * 3.0).ceil().clamp(4, 180);
        newMastery = (newMastery + 0.25).clamp(0.0, 1.0);
        // Hodnocení "Snadné" znamená, že student látku spolehlivě ovládá.
        // Okamžitě posuneme do "Zvládnuto" (masteryScore >= 0.85), aby se v UI přičetlo.
        newMastery = newMastery < 0.85 ? 0.85 : (newMastery + 0.15).clamp(0.0, 1.0);
        break;
    }

    return SrsUpdate(
      intervalDays: newInterval,
      repetitionCount: newRepetition,
      masteryScore: newMastery,
      nextReviewAt: (now ?? DateTime.now()).add(Duration(days: newInterval)),
    );
  }
}
