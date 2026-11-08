import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/models/error_category.dart';
import 'package:aj_tudor/data/models/skill_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Session _session(int id, {required int student, int tutor = 300, int replies = 0, String? level}) => Session(
      id: id,
      startedAt: DateTime(2026, 11, id),
      totalUserUtterances: replies,
      totalErrors: 0,
      estimatedLevel: level,
      levelDetail: level == null ? null : '$level-',
      studentWords: student,
      tutorWords: tutor,
    );

ErrorLog _error(int id, int sessionId, ErrorCategory category) => ErrorLog(
      id: id,
      sessionId: sessionId,
      errorType: 'grammar',
      userSaid: '',
      correctForm: '',
      explanation: '',
      timestamp: DateTime(2026, 11, sessionId),
      inFlashcard: false,
      category: category.id,
    );

void main() {
  test('the last lesson against the average of the lessons before', () {
    final profile = SkillProfile.from(
      [
        _session(1, student: 100, replies: 20),
        _session(2, student: 200, replies: 20),
        _session(3, student: 200, replies: 25, level: 'B1'),
      ],
      [
        _error(1, 1, ErrorCategory.tense),
        _error(2, 1, ErrorCategory.tense),
        _error(3, 2, ErrorCategory.preposition),
        _error(4, 3, ErrorCategory.verbForm),
        _error(5, 3, ErrorCategory.czechWord),
        _error(6, 3, ErrorCategory.other),
      ],
    );

    expect(profile.lastLesson?.id, 3);
    expect(profile.lastLesson?.levelDetail, 'B1-');
    expect(profile.last!.grammarPer100, 0.5);
    expect(profile.last!.vocabularyPer100, 0.5);
    expect(profile.last!.wordsPerReply, 8);
    expect(profile.last!.share, 0.4);
    // Předtím: lekce 1 (2 chyby na 100 slov) a 2 (0,5), průměr 1,25
    expect(profile.previous!.grammarPer100, 1.25);
    expect(profile.previous!.wordsPerReply, 7.5);
  });

  test('short lessons and lessons without the new analysis are left out', () {
    final profile = SkillProfile.from(
      [
        _session(1, student: 30, replies: 5),
        Session(id: 2, startedAt: DateTime(2026, 11, 2), totalUserUtterances: 0, totalErrors: 3),
      ],
      const [],
    );
    expect(profile.isEmpty, isTrue);
  });
}
