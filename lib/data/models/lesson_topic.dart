/// Téma lekce, jak ho vrátil rozbor (oblast z katalogu, název a kdo ho otevřel).
class LessonTopic {
  /// Klíč oblasti z katalogu témat (services/topics/topic_catalog.dart).
  final String areaId;
  final String title;

  /// `student`, `tutor`, nebo `unknown` (zpětně doplněné lekce).
  final String startedBy;

  const LessonTopic({required this.areaId, required this.title, this.startedBy = 'unknown'});
}
