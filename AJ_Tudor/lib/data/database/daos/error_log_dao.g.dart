// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_log_dao.dart';

// ignore_for_file: type=lint
mixin _$ErrorLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionsTable get sessions => attachedDatabase.sessions;
  $ErrorLogsTable get errorLogs => attachedDatabase.errorLogs;
  ErrorLogDaoManager get managers => ErrorLogDaoManager(this);
}

class ErrorLogDaoManager {
  final _$ErrorLogDaoMixin _db;
  ErrorLogDaoManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$ErrorLogsTableTableManager get errorLogs =>
      $$ErrorLogsTableTableManager(_db.attachedDatabase, _db.errorLogs);
}
