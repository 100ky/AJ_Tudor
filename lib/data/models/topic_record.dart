/// Jedno probrané téma z evidence témat (řádek tabulky topic_history).
class TopicRecord {
  final int sessionId;

  /// Klíč oblasti z katalogu témat (services/topics/topic_catalog.dart).
  final String areaId;
  final String title;
  final DateTime discussedAt;

  const TopicRecord({
    required this.sessionId,
    required this.areaId,
    required this.title,
    required this.discussedAt,
  });
}
