import 'package:drift/drift.dart';

@DataClassName('UserProfile')
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withDefault(const Constant('Student'))();
  TextColumn get nativeLanguage => text().withDefault(const Constant('cs'))();
  TextColumn get targetLevel => text().withDefault(const Constant('B1'))();
  TextColumn get recurringErrors => text().withDefault(const Constant('[]'))();
  TextColumn get vocabulary => text().withDefault(const Constant('[]'))();
  TextColumn get topicPreferences => text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastSessionAt => dateTime().nullable()();
  IntColumn get totalSessions => integer().withDefault(const Constant(0))();
}
