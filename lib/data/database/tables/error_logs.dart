import 'package:drift/drift.dart';
import 'sessions.dart';

@DataClassName('ErrorLog')
class ErrorLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get errorType => text()(); // 'grammar' | 'vocabulary' | 'pronunciation'

  /// Jemnější druh chyby (`ErrorCategory.id`); u záznamů z doby před ním chybí.
  TextColumn get category => text().nullable()();
  TextColumn get userSaid => text()();
  TextColumn get correctForm => text()();
  TextColumn get explanation => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get inFlashcard => boolean().withDefault(const Constant(false))();
}
