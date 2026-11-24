import 'package:aj_tudor/services/topics/lesson_topics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topics from the analysis keep only catalog areas, without empty titles and duplicates', () {
    final topics = parseLessonTopics([
      {'area': 'zvirata', 'title': ' Králík Dobas má průjem ', 'startedBy': 'tutor'},
      {'area': 'zvirata', 'title': 'králík dobas má průjem', 'startedBy': 'student'},
      {'area': 'domov', 'title': 'Uskladnění jablek ve sklepě', 'startedBy': 'kdosi'},
      {'area': 'neexistuje', 'title': 'Něco', 'startedBy': 'student'},
      {'area': 'sport', 'title': '', 'startedBy': 'student'},
      'není mapa',
    ]);
    expect(topics.map((t) => '${t.areaId}|${t.title}|${t.startedBy}'), [
      'zvirata|Králík Dobas má průjem|tutor',
      'domov|Uskladnění jablek ve sklepě|unknown',
    ]);
  });

  test('no topics or a malformed value give an empty list, and the count is limited', () {
    expect(parseLessonTopics(null), isEmpty);
    expect(parseLessonTopics('topics'), isEmpty);
    final many = parseLessonTopics([
      for (var i = 0; i < 10; i++) {'area': 'filmy', 'title': 'Film $i', 'startedBy': 'student'},
    ]);
    expect(many, hasLength(maxLessonTopics));
  });
}
