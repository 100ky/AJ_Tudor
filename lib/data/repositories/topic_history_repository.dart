import 'package:drift/drift.dart';

import '../models/lesson_topic.dart';
import '../models/topic_record.dart';
import '../database/app_database.dart';

export '../models/lesson_topic.dart';

/// Evidence témat probraných v lekcích.
class TopicHistoryRepository {
  final AppDatabase _db;

  TopicHistoryRepository(this._db);

  /// Všechna probraná témata jako podklad pro plánovač témat.
  Future<List<TopicRecord>> getAll() async {
    final rows = await (_db.select(_db.topicHistory)..orderBy([(t) => OrderingTerm.asc(t.discussedAt)])).get();
    return [
      for (final row in rows)
        TopicRecord(sessionId: row.sessionId, areaId: row.area, title: row.title, discussedAt: row.discussedAt),
    ];
  }

  /// Zda evidence zatím nemá žádné téma (pak se doplní zpětně ze souhrnů lekcí).
  Future<bool> isEmpty() async {
    final count = _db.topicHistory.id.count();
    final row = await (_db.selectOnly(_db.topicHistory)..addColumns([count])).getSingle();
    return (row.read(count) ?? 0) == 0;
  }

  /// Nahradí témata lekce [sessionId] tématy [topics] (opakovaný rozbor je nezdvojí).
  Future<void> replaceForSession(int sessionId, DateTime discussedAt, List<LessonTopic> topics) async {
    await _db.transaction(() async {
      await (_db.delete(_db.topicHistory)..where((t) => t.sessionId.equals(sessionId))).go();
      for (final topic in topics) {
        await _db.into(_db.topicHistory).insert(TopicHistoryCompanion.insert(
              sessionId: sessionId,
              area: topic.areaId,
              title: topic.title,
              startedBy: Value(topic.startedBy),
              discussedAt: discussedAt,
            ));
      }
    });
  }

  /// Smaže celou evidenci probraných témat (při resetu paměti).
  Future<void> clearAll() => _db.delete(_db.topicHistory).go();
}
