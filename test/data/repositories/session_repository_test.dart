import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late ProfileRepository profileRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    profileRepo = ProfileRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SessionRepository - Sessions & Transcripts CRUD', () {
    test('startNewSession creates session and returns valid ID', () async {
      final res = await repo.startNewSession();
      expect(res.isSuccess, true);
      final sessionId = res.getOrThrow();
      expect(sessionId, greaterThan(0));

      final sessions = await repo.watchAllSessions().first;
      expect(sessions.length, 1);
      expect(sessions.first.id, sessionId);
      expect(sessions.first.endedAt, isNull);
    });

    test('addTranscript and getTranscripts store and retrieve conversation ordered by time', () async {
      final sessionRes = await repo.startNewSession();
      final sessionId = sessionRes.getOrThrow();

      final t1 = await repo.addTranscript(
        sessionId: sessionId,
        speaker: 'user',
        content: 'Hello, I want to practice English.',
      );
      expect(t1.isSuccess, true);

      final t2 = await repo.addTranscript(
        sessionId: sessionId,
        speaker: 'tutor',
        content: 'Hi! Great to hear. What did you do today?',
      );
      expect(t2.isSuccess, true);

      final transcripts = await repo.getTranscripts(sessionId);
      expect(transcripts.length, 2);
      expect(transcripts[0].speaker, 'user');
      expect(transcripts[0].content, 'Hello, I want to practice English.');
      expect(transcripts[1].speaker, 'tutor');
      expect(transcripts[1].content, 'Hi! Great to hear. What did you do today?');
    });

    test('watchTranscripts emits real-time updates when new transcript is added', () async {
      final sessionRes = await repo.startNewSession();
      final sessionId = sessionRes.getOrThrow();

      final stream = repo.watchTranscripts(sessionId);
      expect(await stream.first, isEmpty);

      await repo.addTranscript(
        sessionId: sessionId,
        speaker: 'user',
        content: 'Testing stream message',
      );

      final list = await stream.first;
      expect(list.length, 1);
      expect(list.first.content, 'Testing stream message');
    });

    test('closeSession sets endedAt timestamp', () async {
      final sessionRes = await repo.startNewSession();
      final sessionId = sessionRes.getOrThrow();

      final closeRes = await repo.closeSession(sessionId);
      expect(closeRes.isSuccess, true);

      final sessions = await repo.watchAllSessions().first;
      expect(sessions.first.endedAt, isNotNull);
    });

    test('updateSessionAnalysis updates summary, fluency and total error count', () async {
      final sessionRes = await repo.startNewSession();
      final sessionId = sessionRes.getOrThrow();

      await repo.updateSessionAnalysis(
        sessionId: sessionId,
        topicSummary: 'Weekend trip to Vienna',
        fluencyScore: 0.78,
        totalErrors: 3,
      );

      final sessions = await repo.watchAllSessions().first;
      final session = sessions.first;
      expect(session.topicSummary, 'Weekend trip to Vienna');
      expect(session.fluencyScore, closeTo(0.78, 0.001));
      expect(session.totalErrors, 3);
    });

    test('getRecentTranscripts respects sessionLimit and fetches recent session transcripts', () async {
      final now = DateTime.now();
      final s1 = await db.into(db.sessions).insert(
        SessionsCompanion.insert(startedAt: now.subtract(const Duration(minutes: 2))),
      );
      await repo.addTranscript(sessionId: s1, speaker: 'user', content: 'Session 1 message');

      final s2 = await db.into(db.sessions).insert(
        SessionsCompanion.insert(startedAt: now.subtract(const Duration(minutes: 1))),
      );
      await repo.addTranscript(sessionId: s2, speaker: 'user', content: 'Session 2 message');

      final s3 = await db.into(db.sessions).insert(
        SessionsCompanion.insert(startedAt: now),
      );
      await repo.addTranscript(sessionId: s3, speaker: 'user', content: 'Session 3 message');

      final recent = await repo.getRecentTranscripts(sessionLimit: 2);
      expect(recent.length, 2);
      final contents = recent.map((t) => t.content).toList();
      expect(contents.contains('Session 2 message'), true);
      expect(contents.contains('Session 3 message'), true);
      expect(contents.contains('Session 1 message'), false);
    });

    test('getAllUserTranscripts returns only student lines and respects limit', () async {
      final now = DateTime.now();
      final s = (await repo.startNewSession()).getOrThrow();
      await db.into(db.transcripts).insert(
        TranscriptsCompanion.insert(
          sessionId: s,
          speaker: 'tutor',
          content: 'Tutor prompt',
          timestamp: now.subtract(const Duration(seconds: 10)),
        ),
      );
      await db.into(db.transcripts).insert(
        TranscriptsCompanion.insert(
          sessionId: s,
          speaker: 'user',
          content: 'User reply 1',
          timestamp: now.subtract(const Duration(seconds: 5)),
        ),
      );
      await db.into(db.transcripts).insert(
        TranscriptsCompanion.insert(
          sessionId: s,
          speaker: 'user',
          content: 'User reply 2',
          timestamp: now,
        ),
      );

      final userTranscripts = await repo.getAllUserTranscripts(limit: 1);
      expect(userTranscripts.length, 1);
      expect(userTranscripts.first.content, 'User reply 2'); // desc ordering
    });
  });

  group('SessionRepository - Error Logs CRUD', () {
    test('addErrorLog, getErrorLogs, and watchErrorLogs manage logged errors', () async {
      final sessionRes = await repo.startNewSession();
      final sessionId = sessionRes.getOrThrow();

      final addRes = await repo.addErrorLog(
        sessionId: sessionId,
        errorType: 'grammar',
        userSaid: 'I no have car',
        correctForm: 'I do not have a car',
        explanation: 'Zápor v přítomném čase se tvoří pomocí do not / does not.',
      );
      expect(addRes.isSuccess, true);
      final errorId = addRes.getOrThrow();
      expect(errorId, greaterThan(0));

      final logs = await repo.getErrorLogs(sessionId);
      expect(logs.length, 1);
      expect(logs.first.id, errorId);
      expect(logs.first.userSaid, 'I no have car');
      expect(logs.first.correctForm, 'I do not have a car');
      expect(logs.first.inFlashcard, false);

      final allLogs = await repo.watchAllErrorLogs().first;
      expect(allLogs.length, 1);
    });

    test('getErrorLogsWithoutFlashcard and markErrorLogInFlashcard track processed errors', () async {
      final s1 = (await repo.startNewSession()).getOrThrow();
      final s2 = (await repo.startNewSession()).getOrThrow();
      final e1 = (await repo.addErrorLog(
        sessionId: s1,
        errorType: 'grammar',
        userSaid: 'He go',
        correctForm: 'He goes',
        explanation: '3. osoba',
      )).getOrThrow();
      final e2 = (await repo.addErrorLog(
        sessionId: s2,
        errorType: 'grammar',
        userSaid: 'I has',
        correctForm: 'I have',
        explanation: '1. osoba',
      )).getOrThrow();

      expect((await repo.getErrorLogsWithoutFlashcard()).map((e) => e.id), unorderedEquals([e1, e2]));
      expect((await repo.getErrorLogsWithoutFlashcard(sessionId: s1)).map((e) => e.id), [e1]);

      await repo.markErrorLogInFlashcard(e1);
      expect((await repo.getErrorLogsWithoutFlashcard()).map((e) => e.id), [e2]);
      expect((await repo.getErrorLogs(s1)).single.inFlashcard, true);
    });
  });

  group('SessionRepository - Cascading deleteSession', () {
    test('deleting latest session removes data and clears memoryBriefing', () async {
      await profileRepo.updateUserMemory('Latest briefing notes');
      var profile = await profileRepo.getUserProfile();
      expect(profile?.totalSessions, 1);
      expect(profile?.memoryBriefing, 'Latest briefing notes');

      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Session transcript');
      await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'He go',
        correctForm: 'He goes',
        explanation: '3. osoba sg.',
      );

      final deleteRes = await repo.deleteSession(s);
      expect(deleteRes.isSuccess, true);

      // Verify transcripts and error logs are gone
      expect(await repo.getTranscripts(s), isEmpty);
      expect(await repo.getErrorLogs(s), isEmpty);
      expect(await repo.watchAllSessions().first, isEmpty);

      // Verify profile is updated: since deleted session was latest, memoryBriefing is cleared
      profile = await profileRepo.getUserProfile();
      expect(profile?.totalSessions, 0);
      expect(profile?.memoryBriefing, isNull);
    });

    test('deleting older session decrements totalSessions but preserves latest memoryBriefing', () async {
      await profileRepo.updateUserMemory('Latest briefing');
      // Create s1 with timestamp 1 hour ago
      final s1 = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      final s2 = (await repo.startNewSession()).getOrThrow();

      // Deleting the older session s1
      final deleteRes = await repo.deleteSession(s1);
      expect(deleteRes.isSuccess, true);

      final profile = await profileRepo.getUserProfile();
      expect(profile?.memoryBriefing, 'Latest briefing'); // preserved!
      expect((await repo.watchAllSessions().first).map((s) => s.id), [s2]);
    });
  });
}
