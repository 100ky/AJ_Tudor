import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/data/repositories/topic_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TopicHistoryRepository repo;
  late SessionRepository sessions;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TopicHistoryRepository(db);
    sessions = SessionRepository(db);
  });

  tearDown(() => db.close());

  test('topics of a lesson are stored and a new analysis replaces them', () async {
    final sessionId = (await sessions.startNewSession()).getOrThrow();
    final when = DateTime(2026, 11, 21, 22, 9);
    expect(await repo.isEmpty(), isTrue);

    await repo.replaceForSession(sessionId, when, const [
      LessonTopic(areaId: 'zvirata', title: 'Králík Dobas a jeho zdraví', startedBy: 'tutor'),
      LessonTopic(areaId: 'domov', title: 'Uskladnění sušených jablek ve sklepě'),
    ]);
    expect(await repo.isEmpty(), isFalse);
    var all = await repo.getAll();
    expect(all.map((t) => t.areaId), ['zvirata', 'domov']);
    expect(all.first.discussedAt, when);
    expect(all.first.sessionId, sessionId);

    // Opakovaný rozbor téže lekce témata nezdvojí
    await repo.replaceForSession(sessionId, when, const [LessonTopic(areaId: 'zvirata', title: 'Králík Dobas')]);
    all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.title, 'Králík Dobas');
  });

  test('deleting a lesson deletes its topics', () async {
    final sessionId = (await sessions.startNewSession()).getOrThrow();
    await repo.replaceForSession(sessionId, DateTime(2026, 11, 21), const [LessonTopic(areaId: 'sport', title: 'Běh')]);

    final result = await sessions.deleteSession(sessionId);
    expect(result.isSuccess, isTrue);
    expect(await repo.isEmpty(), isTrue);
  });
}
