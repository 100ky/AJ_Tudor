// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_dao.dart';

// ignore_for_file: type=lint
mixin _$TranscriptDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionsTable get sessions => attachedDatabase.sessions;
  $TranscriptsTable get transcripts => attachedDatabase.transcripts;
  TranscriptDaoManager get managers => TranscriptDaoManager(this);
}

class TranscriptDaoManager {
  final _$TranscriptDaoMixin _db;
  TranscriptDaoManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db.attachedDatabase, _db.transcripts);
}
