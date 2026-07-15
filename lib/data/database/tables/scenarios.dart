import 'package:drift/drift.dart';

@DataClassName('Scenario')
class Scenarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get externalId => text()(); // ID z AI modelu
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get tutorInstruction => text()();
  TextColumn get difficulty => text()();
  BoolColumn get isUsed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
