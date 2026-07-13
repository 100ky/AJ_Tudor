import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/error_logs.dart';

part 'error_log_dao.g.dart';

@DriftAccessor(tables: [ErrorLogs])
class ErrorLogDao extends DatabaseAccessor<AppDatabase> with _$ErrorLogDaoMixin {
  ErrorLogDao(AppDatabase db) : super(db);

  Future<int> logError(int sessionId, String errorType, String userSaid, String correctForm, String explanation) {
    return into(errorLogs).insert(ErrorLogsCompanion(
      sessionId: Value(sessionId),
      errorType: Value(errorType),
      userSaid: Value(userSaid),
      correctForm: Value(correctForm),
      explanation: Value(explanation),
      timestamp: Value(DateTime.now()),
    ));
  }

  Future<List<ErrorLog>> getErrorsForSession(int sessionId) {
    return (select(errorLogs)..where((t) => t.sessionId.equals(sessionId))).get();
  }
}
