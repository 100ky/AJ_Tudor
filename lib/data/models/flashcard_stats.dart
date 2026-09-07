/// Agregovaný model statistik kartiček a stavu ovládnutí látky (Mastery).
class FlashcardStats {
  /// Celkový počet kartiček
  final int totalCards;

  /// Počet kartiček k dnešnímu opakování
  final int dueCards;

  /// Počet zvládnutých kartiček (masteryScore >= 0.8)
  final int masteredCards;

  /// Počet kartiček v procesu učení (0.0 < masteryScore < 0.8)
  final int learningCards;

  /// Počet nových dosud neprocvičených kartiček (masteryScore == 0.0)
  final int newCards;

  /// Průměrné skóre ovládnutí napříč všemi kartičkami (0.0 - 1.0)
  final double averageMastery;

  const FlashcardStats({
    required this.totalCards,
    required this.dueCards,
    required this.masteredCards,
    required this.learningCards,
    required this.newCards,
    required this.averageMastery,
  });

  const FlashcardStats.empty()
      : totalCards = 0,
        dueCards = 0,
        masteredCards = 0,
        learningCards = 0,
        newCards = 0,
        averageMastery = 0.0;

  /// Procento zvládnutých kartiček z celkového počtu (0 až 100).
  int get masteredPercentage =>
      totalCards > 0 ? ((masteredCards / totalCards) * 100).round() : 0;

  /// Procento průměrného ovládnutí látky (0 až 100).
  int get averageMasteryPercentage => (averageMastery * 100).round();
}

