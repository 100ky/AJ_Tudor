import 'package:drift/drift.dart';
import 'sessions.dart';
import 'transcripts.dart';

/// Problém, který student nahlásil u lekce v historii (podklad pro ladění podle logu lekce).
@DataClassName('SessionIssue')
class SessionIssues extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  /// Replika, u které se problém projevil (nepovinné).
  IntColumn get transcriptId => integer().nullable().references(Transcripts, #id)();
  TextColumn get note => text()();
  DateTimeColumn get createdAt => dateTime()();
}
