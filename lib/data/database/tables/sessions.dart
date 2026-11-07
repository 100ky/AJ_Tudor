import 'package:drift/drift.dart';

@DataClassName('Session')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get fluencyScore => real().nullable()();
  IntColumn get totalUserUtterances => integer().withDefault(const Constant(0))();
  IntColumn get totalErrors => integer().withDefault(const Constant(0))();
  TextColumn get topicSummary => text().nullable()();

  /// Úroveň (A1–B2), kterou odhadl rozbor této lekce. Profil z posledních lekcí bere
  /// ustálenou úroveň, aby tutor neměnil styl podle jedné lekce.
  TextColumn get estimatedLevel => text().nullable()();

  /// Kolik slov řekl student a kolik tutor (z uloženého přepisu, spočítá rozbor po lekci).
  IntColumn get studentWords => integer().nullable()();
  IntColumn get tutorWords => integer().nullable()();
}
