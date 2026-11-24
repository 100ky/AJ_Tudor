import 'package:drift/drift.dart';
import 'sessions.dart';

/// Evidence témat: o čem se v lekci mluvilo, v jaké oblasti a kdy.
///
/// Z ní plánovač témat počítá, které oblasti odpočívají a které se mají vrátit
/// (lib/services/topics/topic_planner.dart). Plní ji rozbor po lekci.
@DataClassName('TopicHistoryEntry')
class TopicHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();

  /// Klíč oblasti z katalogu (TopicCatalog), např. "cestovani".
  TextColumn get area => text()();

  /// Konkrétní téma česky, např. „Výlet do Toulovcových Maštalí“.
  TextColumn get title => text()();

  /// Kdo téma otevřel: student, tutor, nebo neznámo (zpětně doplněné lekce).
  TextColumn get startedBy => text().withDefault(const Constant('unknown'))();

  /// Začátek lekce, ve které se o tématu mluvilo.
  DateTimeColumn get discussedAt => dateTime()();
}
