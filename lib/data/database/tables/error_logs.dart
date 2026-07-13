import 'package:drift/drift.dart';
import 'sessions.dart';

@DataClassName('ErrorLog')
class ErrorLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get errorType => text()(); // 'grammar' | 'vocabulary' | 'pronunciation'
  TextColumn get userSaid => text()();
  TextColumn get correctForm => text()();
  TextColumn get explanation => text()();
  DateTimeColumn get timestamp => dateTime()();
}
