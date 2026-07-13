import 'package:drift/drift.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get fluencyScore => real().nullable()();       
  IntColumn get totalUserUtterances => integer().withDefault(const Constant(0))();
  IntColumn get totalErrors => integer().withDefault(const Constant(0))();
  TextColumn get topicSummary => text().nullable()();        
}
