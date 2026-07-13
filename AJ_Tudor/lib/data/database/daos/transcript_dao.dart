import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transcripts.dart';

part 'transcript_dao.g.dart';

@DriftAccessor(tables: [Transcripts])
class TranscriptDao extends DatabaseAccessor<AppDatabase> with _$TranscriptDaoMixin {
  TranscriptDao(AppDatabase db) : super(db);

  Future<int> addTranscript(int sessionId, String speaker, String content, {String? correctedForm}) {
    return into(transcripts).insert(TranscriptsCompanion(
      sessionId: Value(sessionId),
      speaker: Value(speaker),
      content: Value(content),
      timestamp: Value(DateTime.now()),
      correctedForm: Value(correctedForm),
    ));
  }

  Future<List<Transcript>> getTranscriptsForSession(int sessionId) {
    return (select(transcripts)..where((t) => t.sessionId.equals(sessionId))..orderBy([(t) => OrderingTerm.asc(t.timestamp)])).get();
  }
}
