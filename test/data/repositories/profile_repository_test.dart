import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileRepository - User Profile & Memory Operations', () {
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

    test('UserProfileLists decodes JSON list columns and tolerates invalid JSON', () async {
      await repo.updateUserMemory('Init');
      await repo.updateUserVocabulary(['apple', 'banana']);
      await repo.updateUserRecurringErrors(['Articles a/the']);
      await repo.addUserFact('Má psa');

      final profile = (await repo.getUserProfile())!;
      expect(profile.vocabularyList, ['apple', 'banana']);
      expect(profile.recurringErrorsList, ['Articles a/the']);
      expect(profile.userFactsList, ['Má psa']);

      expect(profile.copyWith(vocabulary: 'not json').vocabularyList, isEmpty);
      expect(profile.copyWith(userFacts: '').userFactsList, isEmpty);
      expect(profile.copyWith(recurringErrors: '{"a": 1}').recurringErrorsList, isEmpty);
    });
  });

  group('ProfileRepository - User Facts ("O mně") & Prepared Topic', () {
    setUp(() async {
      // Initialize default user profile
      await repo.updateUserMemory('Test briefing');
    });

    test('updateUserFacts, addUserFact, and getUserFacts should manage facts without duplicates', () async {
      final initialFacts = await repo.getUserFacts();
      expect(initialFacts, isEmpty);

      // Add single fact
      await repo.addUserFact('Má psa jménem Max');
      final facts1 = await repo.getUserFacts();
      expect(facts1.length, 1);
      expect(facts1.first, 'Má psa jménem Max');

      // Add duplicate fact (should not be duplicated)
      await repo.addUserFact('má psa jménem max');
      final facts2 = await repo.getUserFacts();
      expect(facts2.length, 1);

      // Add multiple facts
      await repo.updateUserFacts(['Pracuje jako programátor', 'Rád jezdí na kole']);
      final facts3 = await repo.getUserFacts();
      expect(facts3.length, 3);
      expect(facts3.contains('Pracuje jako programátor'), true);
      expect(facts3.contains('Rád jezdí na kole'), true);

      // Remove fact
      await repo.removeUserFact('Má psa jménem Max');
      final facts4 = await repo.getUserFacts();
      expect(facts4.length, 2);
      expect(facts4.contains('Má psa jménem Max'), false);
    });

    test('savePreparedTopic, getPreparedTopic, and clearPreparedTopic should persist and clear topics', () async {
      expect(await repo.getPreparedTopic(), isNull);

      const topicJson = '{"title":"Cestování vlakem","openerEn":"Hey! Do you like night trains?","rationale":"Fresh topic"}';
      await repo.savePreparedTopic(topicJson);

      final saved = await repo.getPreparedTopic();
      expect(saved, isNotNull);
      expect(saved, topicJson);

      await repo.clearPreparedTopic();
      expect(await repo.getPreparedTopic(), isNull);
    });

    test('resetUserMemory should also reset user facts and prepared topic', () async {
      await repo.addUserFact('Baví ho tenis');
      await repo.savePreparedTopic('{"title":"Tenis"}');

      expect((await repo.getUserFacts()).length, 1);
      expect(await repo.getPreparedTopic(), isNotNull);

      await repo.resetUserMemory();

      expect(await repo.getUserFacts(), isEmpty);
      expect(await repo.getPreparedTopic(), isNull);
    });
  });
}
