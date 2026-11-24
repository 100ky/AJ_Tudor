import '../../data/models/lesson_topic.dart';
import 'topic_catalog.dart';

/// Nejvýš tolik témat z jedné lekce se zapíše do evidence.
const int maxLessonTopics = 6;

/// Témata lekce z odpovědi rozboru (`topics`): jen oblasti z katalogu, bez prázdných
/// názvů a opakování, nejvýš [maxLessonTopics].
List<LessonTopic> parseLessonTopics(Object? topics) {
  if (topics is! List) return const [];
  final result = <LessonTopic>[];
  final seen = <String>{};
  for (final item in topics) {
    if (item is! Map) continue;
    final area = item['area']?.toString().trim() ?? '';
    final title = item['title']?.toString().trim() ?? '';
    if (TopicCatalog.byId(area) == null || title.isEmpty) continue;
    if (!seen.add('$area|${title.toLowerCase()}')) continue;
    final startedBy = item['startedBy']?.toString();
    result.add(LessonTopic(
      areaId: area,
      title: title,
      startedBy: startedBy == 'student' || startedBy == 'tutor' ? startedBy! : 'unknown',
    ));
    if (result.length >= maxLessonTopics) break;
  }
  return result;
}
