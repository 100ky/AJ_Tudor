import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sessions.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(AppDatabase db) : super(db);

  Future<int> createSession() => into(sessions).insert(SessionsCompanion(
    startedAt: Value(DateTime.now()),
  ));

  Future<void> endSession(int id, double fluencyScore, String summary, int userUtterances, int errors) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        endedAt: Value(DateTime.now()),
        fluencyScore: Value(fluencyScore),
        topicSummary: Value(summary),
        totalUserUtterances: Value(userUtterances),
        totalErrors: Value(errors),
      ),
    );
  }

  Future<Session> getSession(int id) => (select(sessions)..where((t) => t.id.equals(id))).getSingle();
  Future<List<Session>> getAllSessions() => (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).get();
}
