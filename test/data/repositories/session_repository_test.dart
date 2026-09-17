import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class _FakeBatchClient extends GeminiBatchClient {
  final String Function(String prompt) handler;
  _FakeBatchClient(this.handler) : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) async {
    return handler(text);
  }
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
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
  });

  group('SessionRepository - Cascading deleteSession', () {
    test('deleting latest session removes data and clears memoryBriefing', () async {
      await repo.updateUserMemory('Latest briefing notes');
      var profile = await repo.getUserProfile();
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
      profile = await repo.getUserProfile();
      expect(profile?.totalSessions, 0);
      expect(profile?.memoryBriefing, isNull);
    });

    test('deleting older session decrements totalSessions but preserves latest memoryBriefing', () async {
      await repo.updateUserMemory('Latest briefing');
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

      final profile = await repo.getUserProfile();
      expect(profile?.memoryBriefing, 'Latest briefing'); // preserved!
      expect((await repo.watchAllSessions().first).map((s) => s.id), [s2]);
    });
  });

  group('SessionRepository - User Profile & Memory Operations', () {
    test('updateUserMemory creates profile if absent and increments session count on subsequent calls', () async {
      expect(await repo.getUserProfile(), isNull);

      await repo.updateUserMemory('Initial briefing');
      var profile = await repo.getUserProfile();
      expect(profile, isNotNull);
      expect(profile?.memoryBriefing, 'Initial briefing');
      expect(profile?.totalSessions, 1);
      expect(profile?.targetLevel, 'B1');

      await repo.updateUserMemory('Second briefing');
      profile = await repo.getUserProfile();
      expect(profile?.memoryBriefing, 'Second briefing');
      expect(profile?.totalSessions, 2);
    });

    test('updateUserVocabulary appends, deduplicates and keeps maximum 50 newest words', () async {
      await repo.updateUserMemory('Init');

      await repo.updateUserVocabulary(['apple', 'banana', 'cherry']);
      var profile = await repo.getUserProfile();
      List<dynamic> vocab = jsonDecode(profile!.vocabulary);
      expect(vocab, ['apple', 'banana', 'cherry']);

      // Adding duplicate should move it to the end (most recent)
      await repo.updateUserVocabulary(['banana', 'date']);
      profile = await repo.getUserProfile();
      vocab = jsonDecode(profile!.vocabulary);
      expect(vocab, ['apple', 'cherry', 'banana', 'date']);

      // Adding 60 words to check 50 words trimming
      final manyWords = List.generate(60, (i) => 'word_$i');
      await repo.updateUserVocabulary(manyWords);
      profile = await repo.getUserProfile();
      vocab = jsonDecode(profile!.vocabulary);
      expect(vocab.length, 50);
      expect(vocab.first, 'word_10');
      expect(vocab.last, 'word_59');
    });

    test('updateUserRecurringErrors deduplicates and keeps max 10 errors', () async {
      await repo.updateUserMemory('Init');

      await repo.updateUserRecurringErrors(['Past simple vs present perfect', 'Prepositions at/on']);
      var profile = await repo.getUserProfile();
      List<dynamic> errors = jsonDecode(profile!.recurringErrors);
      expect(errors.length, 2);

      // Adding duplicates does not duplicate
      await repo.updateUserRecurringErrors(['Prepositions at/on', 'Articles a/the']);
      profile = await repo.getUserProfile();
      errors = jsonDecode(profile!.recurringErrors);
      expect(errors.length, 3);

      // Adding 15 items should trim to max 10
      final manyErrors = List.generate(15, (i) => 'Error #$i');
      await repo.updateUserRecurringErrors(manyErrors);
      profile = await repo.getUserProfile();
      errors = jsonDecode(profile!.recurringErrors);
      expect(errors.length, 10);
    });

    test('pruneResolvedErrors removes resolved errors with case-insensitive fuzzy matching', () async {
      await repo.updateUserMemory('Init');
      await repo.updateUserRecurringErrors([
        'Chyba v předložkách at/on',
        'Minulý čas slovesa go',
        'Člen the před městy',
      ]);

      // Prune matching resolved errors
      await repo.pruneResolvedErrors(['předložkách at/on', 'člen the']);

      final profile = await repo.getUserProfile();
      final List<dynamic> errors = jsonDecode(profile!.recurringErrors);
      expect(errors.length, 1);
      expect(errors.first, 'Minulý čas slovesa go');
    });

    test('updateTargetLevel updates targetLevel on existing and creates profile if missing', () async {
      await repo.updateTargetLevel('B2');
      var profile = await repo.getUserProfile();
      expect(profile?.targetLevel, 'B2');

      await repo.updateTargetLevel('C1');
      profile = await repo.getUserProfile();
      expect(profile?.targetLevel, 'C1');
    });

    test('getLatestBriefing returns Result with briefing or null', () async {
      final b1 = await repo.getLatestBriefing();
      expect(b1.isSuccess, true);
      expect(b1.valueOrNull, isNull);

      await repo.updateUserMemory('A briefing to remember');
      final b2 = await repo.getLatestBriefing();
      expect(b2.isSuccess, true);
      expect(b2.valueOrNull, 'A briefing to remember');
    });
  });

  group('SessionRepository - Scenarios Management', () {
    test('replaceScenarios deletes unused scenarios and inserts new ones within transaction', () async {
      // Insert an unused scenario and a used scenario
      final custom1 = await repo.insertScenario(
        title: 'Custom unused',
        description: 'Desc 1',
        tutorInstruction: 'Instruction 1',
      );
      final custom2 = await repo.insertScenario(
        title: 'Custom used',
        description: 'Desc 2',
        tutorInstruction: 'Instruction 2',
      );
      await repo.markScenarioUsed(custom2.id);

      // Now replace with a new scenario
      final newScenario = Scenario(
        id: 0,
        externalId: 'ai_new_1',
        title: 'At the airport',
        description: 'Check-in luggage',
        tutorInstruction: 'Act as airline staff',
        difficulty: 'medium',
        isUsed: false,
        createdAt: DateTime.now(),
      );

      await repo.replaceScenarios([newScenario]);

      final available = await repo.watchAvailableScenarios().first;
      expect(available.length, 1);
      expect(available.first.title, 'At the airport');

      // The used scenario should still exist in database
      final allScenarios = await (db.select(db.scenarios)).get();
      expect(allScenarios.any((s) => s.id == custom2.id && s.isUsed == true), true);
      expect(allScenarios.any((s) => s.id == custom1.id), false);
    });
  });

  group('SessionRepository - Flashcards & Duplication Logic', () {
    test('addFlashcard rejects duplicates with identical backText or errorLogId', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      final errId = (await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'I go',
        correctForm: 'I went',
        explanation: 'Past tense',
      )).getOrThrow();

      final res1 = await repo.addFlashcard(
        frontText: 'Šel jsem',
        backText: 'I went',
        explanation: 'Past tense of go is went',
        errorLogId: errId,
      );
      expect(res1.isSuccess, true);
      final firstCardId = res1.getOrThrow();

      // Duplicate by errorLogId
      final res2 = await repo.addFlashcard(
        frontText: 'Different front',
        backText: 'Different back',
        explanation: 'Different explanation',
        errorLogId: errId,
      );
      expect(res2.isSuccess, true);
      expect(res2.getOrThrow(), firstCardId);

      // Duplicate by backText (case-insensitive)
      final res3 = await repo.addFlashcard(
        frontText: 'Jiný český překlad',
        backText: '  i went  ',
        explanation: 'Minulý čas',
      );
      expect(res3.isSuccess, true);
      expect(res3.getOrThrow(), firstCardId);

      // Total cards in database should still be 1
      final allCards = await repo.getAllFlashcards();
      expect(allCards.length, 1);
    });

    test('addFlashcard marks sourceSentence matching transcripts and error logs as inFlashcard', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(
        sessionId: s,
        speaker: 'user',
        content: 'I have 20 years and I study math.',
      );
      final errId = (await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'I have 20 years',
        correctForm: 'I am 20 years old',
        explanation: 'Věk slovesem be',
      )).getOrThrow();

      await repo.addFlashcard(
        frontText: 'Je mi 20 let',
        backText: 'I am 20 years old',
        explanation: 'Věk se vyjadřuje pomocí to be',
        sourceSentence: 'I have 20 years',
        errorLogId: errId,
      );

      final transcripts = await repo.getTranscripts(s);
      expect(transcripts.first.inFlashcard, true);

      final errorLogs = await repo.getErrorLogs(s);
      expect(errorLogs.first.inFlashcard, true);
    });

    test('deleteFlashcard and updateFlashcardFrontText', () async {
      final res = await repo.addFlashcard(
        frontText: 'Původní text',
        backText: 'Original text',
        explanation: 'Vysvětlení',
      );
      final cardId = res.getOrThrow();

      await repo.updateFlashcardFrontText(cardId, 'Upravený český text');
      var card = (await repo.getAllFlashcards()).first;
      expect(card.frontText, 'Upravený český text');

      final delRes = await repo.deleteFlashcard(cardId);
      expect(delRes.isSuccess, true);
      expect(await repo.getAllFlashcards(), isEmpty);
    });

    test('removeDuplicateFlashcards keeps highest masteryScore card', () async {
      // Manually insert 3 cards with same backText but varying mastery
      final now = DateTime.now();
      final id1 = await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 1',
          backText: 'Dog',
          explanation: 'Zvire',
          masteryScore: const Value(0.2),
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      final id2 = await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 2',
          backText: 'dog', // case-insensitive
          explanation: 'Zvire',
          masteryScore: const Value(0.9), // highest!
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      final id3 = await db.into(db.flashcards).insert(
        FlashcardsCompanion.insert(
          frontText: 'Pes 3',
          backText: 'DOG',
          explanation: 'Zvire',
          masteryScore: const Value(0.5),
          nextReviewAt: now,
          createdAt: now,
        ),
      );

      final removedCount = await repo.removeDuplicateFlashcards();
      expect(removedCount, 2);

      final remaining = await repo.getAllFlashcards();
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
      expect(remaining.first.masteryScore, 0.9);
    });

    test('generateFlashcardsFromErrors generates cards and filters out invalid sentences', () async {
      final s = (await repo.startNewSession()).getOrThrow();

      // Valid error
      await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'She do not like tea',
        correctForm: 'She does not like tea',
        explanation: '3. os. jednotného čísla (nemá ráda čaj)',
      );

      // Filtered out: userSaid == correctForm
      await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'Identical sentence',
        correctForm: 'Identical sentence',
        explanation: 'Not an error',
      );

      // Filtered out: tutor monologue / AI phrase
      await repo.addErrorLog(
        sessionId: s,
        errorType: 'grammar',
        userSaid: 'Wait a minute, as an AI tutor I think...',
        correctForm: 'Wait a minute...',
        explanation: 'Irrelevant',
      );

      final client = _FakeBatchClient((prompt) => 'Ona nemá ráda čaj');
      final genRes = await repo.generateFlashcardsFromErrors(
        sessionId: s,
        limit: 10,
        geminiClient: client,
      );

      expect(genRes.isSuccess, true);
      expect(genRes.getOrThrow(), 1);

      final cards = await repo.getAllFlashcards();
      expect(cards.length, 1);
      expect(cards.first.backText, 'She does not like tea');
      expect(cards.first.frontText, 'Ona nemá ráda čaj');

      // Error logs should now be marked as inFlashcard = true
      final logs = await repo.getErrorLogs(s);
      expect(logs.every((l) => l.inFlashcard), true);
    });
  });
}
