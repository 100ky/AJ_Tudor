import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/sessions.dart';
import 'tables/transcripts.dart';
import 'tables/user_profiles.dart';
import 'tables/error_logs.dart';

import 'daos/session_dao.dart';
import 'daos/transcript_dao.dart';
import 'daos/user_profile_dao.dart';
import 'daos/error_log_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Sessions, Transcripts, UserProfiles, ErrorLogs],
  daos: [SessionDao, TranscriptDao, UserProfileDao, ErrorLogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'aj_tudor_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
