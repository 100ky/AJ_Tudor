import '../database/app_database.dart';
import 'error_category.dart';
import 'progress_trends.dart';

/// Ukazatele jedné lekce nebo průměr několika lekcí.
class SkillSnapshot {
  /// Chyby v gramatice (čas, tvar slovesa, předložky, slovosled) na 100 slov studenta.
  final double grammarPer100;

  /// Česká slova a špatně zvolená slova na 100 slov studenta.
  final double vocabularyPer100;

  /// Průměrný počet slov v replice studenta; null, když lekce počet replik nezná.
  final double? wordsPerReply;

  /// Podíl slov studenta v lekci (0–1).
  final double share;

  const SkillSnapshot({
    required this.grammarPer100,
    required this.vocabularyPer100,
    required this.share,
    this.wordsPerReply,
  });

  /// Kolik slov student průměrně řekne na jednu chybu v gramatice (víc je líp);
  /// null, když v gramatice chybu neudělal.
  double? get wordsPerGrammarError => grammarPer100 > 0 ? 100 / grammarPer100 : null;

  /// Kolik slov připadá na jedno české nebo špatně zvolené slovo (víc je líp);
  /// null, když takové slovo neřekl.
  double? get wordsPerVocabularyError => vocabularyPer100 > 0 ? 100 / vocabularyPer100 : null;
}

/// Jak se ukazatel poslední lekce liší od průměru lekcí předtím.
enum SkillChange { better, same, worse }

/// Profil dovedností: poslední lekce proti průměru lekcí předtím.
///
/// Úroveň A1–B2 z rozboru je hrubá a mezi lekcemi skoro stejná. Tady je vidět, co se
/// v ní děje: kolik chyb v gramatice a ve slovní zásobě připadá na 100 slov, jak dlouhé
/// má student repliky a kolik mluví.
class SkillProfile {
  /// Lekce s méně slovy studenta se nepočítá, ukazatele by byly náhodné.
  static const int minStudentWords = ProgressTrends.minStudentWords;

  /// Z kolika lekcí před poslední se počítá průměr.
  static const int previousLessons = 4;

  static const List<ErrorCategory> _grammar = [
    ErrorCategory.tense,
    ErrorCategory.verbForm,
    ErrorCategory.preposition,
    ErrorCategory.wordOrder,
  ];
  static const List<ErrorCategory> _vocabulary = [ErrorCategory.czechWord, ErrorCategory.wordChoice];

  /// Poslední lekce s rozborem podle druhů chyb.
  final Session? lastLesson;
  final SkillSnapshot? last;

  /// Průměr až [previousLessons] lekcí před ní; null, když ještě nejsou.
  final SkillSnapshot? previous;

  /// Poslední lekce a až [previousLessons] lekcí před ní, od nejstarší (pro graf vývoje).
  final List<SkillSnapshot> history;

  const SkillProfile({this.lastLesson, this.last, this.previous, this.history = const []});

  bool get isEmpty => last == null;

  /// Spočítá profil z lekcí [sessions] a chyb [errors].
  static SkillProfile from(List<Session> sessions, List<ErrorLog> errors) {
    final lessons = [
      for (final s in sessions)
        if (ProgressTrends.isCategorized(s) && (s.studentWords ?? 0) >= minStudentWords) s,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (lessons.isEmpty) return const SkillProfile();

    final snapshots = [for (final s in lessons.take(previousLessons + 1)) _snapshot(s, errors)];
    final earlier = snapshots.skip(1).toList();
    return SkillProfile(
      lastLesson: lessons.first,
      last: snapshots.first,
      previous: earlier.isEmpty ? null : _average(earlier),
      history: snapshots.reversed.toList(),
    );
  }

  /// Změna chyb v gramatice (méně je líp, rozdíl do 0,5 na 100 slov je šum).
  SkillChange? get grammarChange =>
      _change(last?.grammarPer100, previous?.grammarPer100, lowerIsBetter: true, noise: 0.5);

  /// Změna českých a špatně zvolených slov (méně je líp, rozdíl do 0,5 na 100 slov je šum).
  SkillChange? get vocabularyChange =>
      _change(last?.vocabularyPer100, previous?.vocabularyPer100, lowerIsBetter: true, noise: 0.5);

  /// Změna délky odpovědí (víc je líp, rozdíl do 1 slova je šum).
  SkillChange? get repliesChange =>
      _change(last?.wordsPerReply, previous?.wordsPerReply, lowerIsBetter: false, noise: 1);

  /// Změna podílu řeči studenta (víc je líp, rozdíl do 5 procentních bodů je šum).
  SkillChange? get shareChange => _change(last?.share, previous?.share, lowerIsBetter: false, noise: 0.05);

  /// Null, když není s čím srovnat.
  static SkillChange? _change(double? now, double? before, {required bool lowerIsBetter, required double noise}) {
    if (now == null || before == null) return null;
    if ((now - before).abs() <= noise) return SkillChange.same;
    return (lowerIsBetter ? now < before : now > before) ? SkillChange.better : SkillChange.worse;
  }

  static SkillSnapshot _snapshot(Session session, List<ErrorLog> errors) {
    final words = session.studentWords!;
    int count(List<ErrorCategory> categories) => errors
        .where((e) => e.sessionId == session.id && categories.any((c) => c.id == e.category))
        .length;
    return SkillSnapshot(
      grammarPer100: count(_grammar) * 100 / words,
      vocabularyPer100: count(_vocabulary) * 100 / words,
      wordsPerReply: session.totalUserUtterances > 0 ? words / session.totalUserUtterances : null,
      share: ProgressTrends.studentShare(session) ?? 0,
    );
  }

  static SkillSnapshot _average(List<SkillSnapshot> items) {
    double mean(Iterable<double> values) => values.reduce((a, b) => a + b) / values.length;
    final replies = [for (final s in items) ?s.wordsPerReply];
    return SkillSnapshot(
      grammarPer100: mean(items.map((s) => s.grammarPer100)),
      vocabularyPer100: mean(items.map((s) => s.vocabularyPer100)),
      wordsPerReply: replies.isEmpty ? null : mean(replies),
      share: mean(items.map((s) => s.share)),
    );
  }
}
