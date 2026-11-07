import '../database/app_database.dart';
import 'error_category.dart';

/// Kolik chyb jednoho druhu připadá na lekci v posledních lekcích a v těch předtím.
class CategoryTrend {
  final ErrorCategory category;

  /// Průměr na lekci v posledních lekcích.
  final double recent;

  /// Průměr na lekci v lekcích předtím; null, když ještě nejsou.
  final double? previous;

  const CategoryTrend({required this.category, required this.recent, this.previous});

  /// Ubylo chyb (o víc, než je jedna chyba za tři lekce).
  bool get improved => previous != null && recent < previous! - 0.4;

  /// Přibylo chyb.
  bool get worse => previous != null && recent > previous! + 0.4;
}

/// Co se zlepšuje: chyby podle druhu a podíl řeči studenta v posledních lekcích.
class ProgressTrends {
  /// Kolik lekcí se porovnává (poslední a stejný počet předtím).
  static const int window = 3;

  /// Z kolika lekcí se počítá průměrný podíl řeči.
  static const int shareWindow = 5;

  /// Druhy chyb od nejčastějšího v posledních lekcích.
  final List<CategoryTrend> categories;

  /// Lekce s rozborem podle druhů chyb (starší rozbory druhy neznají).
  final int analysedLessons;

  /// Podíl slov studenta v poslední lekci a průměr posledních lekcí (0–1).
  final double? lastShare;
  final double? averageShare;

  const ProgressTrends({
    required this.categories,
    required this.analysedLessons,
    this.lastShare,
    this.averageShare,
  });

  bool get isEmpty => categories.isEmpty && lastShare == null;

  /// Spočítá trendy z lekcí [sessions] a chyb [errors].
  ///
  /// Porovnávají se jen lekce, které už rozbor dělil podle druhů chyb (mají odhad úrovně),
  /// jinak by starší lekce vypadaly jako bez chyb.
  static ProgressTrends from(List<Session> sessions, List<ErrorLog> errors) {
    final newestFirst = [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final analysed = newestFirst.where((s) => s.estimatedLevel != null).toList();
    final recent = analysed.take(window).toList();
    final previous = analysed.skip(window).take(window).toList();

    double perLesson(List<Session> group, ErrorCategory category) {
      final ids = {for (final s in group) s.id};
      final count = errors.where((e) => ids.contains(e.sessionId) && e.category == category.id).length;
      return count / group.length;
    }

    final categories = <CategoryTrend>[
      if (recent.isNotEmpty)
        for (final category in ErrorCategory.values)
          CategoryTrend(
            category: category,
            recent: perLesson(recent, category),
            previous: previous.isEmpty ? null : perLesson(previous, category),
          ),
    ].where((t) => t.recent > 0 || (t.previous ?? 0) > 0).toList()
      ..sort((a, b) => b.recent.compareTo(a.recent));

    final shares = [for (final s in newestFirst) ?studentShare(s)].take(shareWindow).toList();

    return ProgressTrends(
      categories: categories,
      analysedLessons: analysed.length,
      lastShare: shares.isEmpty ? null : shares.first,
      averageShare: shares.isEmpty ? null : shares.reduce((a, b) => a + b) / shares.length,
    );
  }

  /// Podíl slov studenta v lekci [session] (0–1), když je známý.
  static double? studentShare(Session session) {
    final student = session.studentWords;
    final tutor = session.tutorWords;
    if (student == null || tutor == null || student + tutor == 0) return null;
    return student / (student + tutor);
  }

  /// Gramatický cíl z lekcí [sessions] a chyb [errors]: nejčastější gramatický druh chyby
  /// v posledních [lessons] lekcích s rozborem podle druhů.
  static ErrorCategory? recentGrammarGoal(List<Session> sessions, List<ErrorLog> errors, {int lessons = 5}) {
    final analysed = [...sessions.where((s) => s.estimatedLevel != null)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final ids = {for (final s in analysed.take(lessons)) s.id};
    return grammarGoal(errors.where((e) => ids.contains(e.sessionId)));
  }

  /// Gramatický cíl lekce: nejčastější gramatický druh chyby v [errors] z posledních lekcí.
  /// Null, když žádná taková chyba není.
  static ErrorCategory? grammarGoal(Iterable<ErrorLog> errors) {
    final counts = <ErrorCategory, int>{};
    for (final error in errors) {
      final category = ErrorCategory.parse(error.category);
      if (category == null || !ErrorCategory.grammarGoals.contains(category)) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    // Při shodě rozhoduje pořadí v ErrorCategory.grammarGoals (čas slovesa první)
    return ErrorCategory.grammarGoals.where(counts.containsKey).reduce((a, b) => counts[b]! > counts[a]! ? b : a);
  }
}
