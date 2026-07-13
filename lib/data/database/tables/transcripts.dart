import 'package:drift/drift.dart';
import 'sessions.dart';

@DataClassName('Transcript')
class Transcripts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get speaker => text()(); // 'user' | 'tutor'
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get correctedForm => text().nullable()();
}
