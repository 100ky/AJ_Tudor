import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/error_category.dart';
import 'package:aj_tudor/data/models/progress_trends.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lekce; s [level] jako po novém rozboru (ten ukládá i počty slov).
Session _session(int id, {String? level, int? student, int? tutor}) => Session(
      id: id,
      startedAt: DateTime(2026, 11, id),
      totalUserUtterances: 0,
      totalErrors: 0,
      estimatedLevel: level,
      studentWords: student ?? (level != null ? 200 : null),
      tutorWords: tutor ?? (level != null ? 200 : null),
    );

ErrorLog _error(int sessionId, ErrorCategory? category) => ErrorLog(
      id: sessionId * 100 + (category?.index ?? 99),
      sessionId: sessionId,
      errorType: 'grammar',
      userSaid: '',
      correctForm: '',
      explanation: '',
      timestamp: DateTime(2026, 11, sessionId),
      inFlashcard: false,
      category: category?.id,
    );

void main() {
  group('ProgressTrends', () {
    test('compares errors per lesson in the last three lessons with the three before', () {
      final sessions = [for (var i = 1; i <= 6; i++) _session(i, level: 'B1'), _session(7)];
      final errors = [
        // Předtím (lekce 1–3) šest chyb v čase, teď (4–6) tři
        for (final id in [1, 1, 2, 2, 3, 3]) _error(id, ErrorCategory.tense),
        for (final id in [4, 5, 6]) _error(id, ErrorCategory.tense),
        _error(6, ErrorCategory.preposition),
        // Lekce bez rozboru podle druhů se nepočítá
        _error(7, ErrorCategory.tense),
      ];

      final trends = ProgressTrends.from(sessions, errors);
      expect(trends.analysedLessons, 6);
      final tense = trends.categories.first;
      expect(tense.category, ErrorCategory.tense);
      expect(tense.recent, 1.0);
      expect(tense.previous, 2.0);
      expect(tense.improved, isTrue);
      final preposition = trends.categories.firstWhere((t) => t.category == ErrorCategory.preposition);
      expect(preposition.worse, isFalse); // jedna chyba za tři lekce je šum
      // Počty pro „předtím → teď“: 6 → 3 ve třech a třech lekcích
      expect(tense.previousCount, 6);
      expect(tense.recentCount, 3);
      expect(trends.recentLessons, 3);
      expect(trends.previousLessons, 3);
    });

    test('a lesson where the student said almost nothing counts neither in errors nor in the share', () {
      // 9. 11.: lekce 24 skončila po úvodu tutora (0 slov studenta, 30 slov tutora)
      final trends = ProgressTrends.from(
        [_session(1, student: 300, tutor: 300), _session(2, student: 0, tutor: 30)],
        [_error(1, ErrorCategory.tense), _error(1, ErrorCategory.tense)],
      );
      expect(trends.analysedLessons, 1);
      expect(trends.categories.single.recent, 2);
      expect(trends.averageShare, 0.5);
      expect(trends.lastShare, 0.5);
    });

    test('without older lessons there is nothing to compare yet', () {
      final trends = ProgressTrends.from([_session(1, level: 'B1')], [_error(1, ErrorCategory.verbForm)]);
      expect(trends.categories.single.previous, isNull);
      expect(trends.categories.single.improved, isFalse);
    });

    test('the student share of words comes from the latest lessons', () {
      final trends = ProgressTrends.from(
        [_session(1, student: 100, tutor: 300), _session(2, student: 300, tutor: 300), _session(3)],
        const [],
      );
      expect(trends.lastShare, 0.5);
      expect(trends.averageShare, closeTo(0.375, 1e-9));
      expect(ProgressTrends.studentShare(_session(4)), isNull);
    });

    test('the grammar goal is the most frequent grammar error, ties go to the verb tense', () {
      expect(ProgressTrends.grammarGoal(const []), isNull);
      expect(
        ProgressTrends.grammarGoal([
          _error(1, ErrorCategory.preposition),
          _error(2, ErrorCategory.preposition),
          _error(3, ErrorCategory.tense),
          _error(4, ErrorCategory.czechWord),
          _error(5, ErrorCategory.czechWord),
          _error(6, ErrorCategory.czechWord),
        ]),
        ErrorCategory.preposition,
      );
      expect(
        ProgressTrends.grammarGoal([_error(1, ErrorCategory.preposition), _error(2, ErrorCategory.tense)]),
        ErrorCategory.tense,
      );
      // Jen lekce s rozborem podle druhů
      expect(
        ProgressTrends.recentGrammarGoal(
          [_session(1, level: 'B1'), _session(2)],
          [_error(1, ErrorCategory.verbForm), _error(2, ErrorCategory.tense), _error(2, ErrorCategory.tense)],
        ),
        ErrorCategory.verbForm,
      );
    });
  });
}
