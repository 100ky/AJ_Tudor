import 'package:drift/drift.dart';

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withDefault(const Constant('Student'))();
  TextColumn get nativeLanguage => text().withDefault(const Constant('cs'))();
  TextColumn get targetLevel => text().withDefault(const Constant('B1'))();
  TextColumn get recurringErrors => text()();                
  TextColumn get vocabulary => text()();                     
  TextColumn get topicPreferences => text()();               
  DateTimeColumn get lastSessionAt => dateTime().nullable()();
  IntColumn get totalSessions => integer().withDefault(const Constant(0))();
}
