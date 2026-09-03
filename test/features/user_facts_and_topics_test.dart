import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

void main() {
  group('SessionRepository User Facts ("O mně") Tests', () {
    late AppDatabase db;
    late SessionRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = SessionRepository(db);

      // Initialize default user profile
      await repo.updateUserMemory('Test briefing');
    });

    tearDown(() async {
      await db.close();
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

  group('SystemPromptBuilder Tests for User Facts & Topic Preparation', () {
    test('buildTutorPrompt includes user facts and anti-repetition rules', () {
      const facts = '["Má psa jménem Rex", "Pracuje v IT"]';
      final prompt = SystemPromptBuilder.buildTutorPrompt(
        userFacts: facts,
        targetLevel: 'B1',
      );

      expect(prompt.contains('CO VÍŠ O STUDENTOVI ("O MNĚ" / OSOBNÍ FAKTA)'), true);
      expect(prompt.contains('Má psa jménem Rex'), true);
      expect(prompt.contains('PŘÍSNÝ ZÁKAZ OPAKOVANÝCH ZÁKLADNÍCH DOTAZŮ'), true);
      expect(prompt.contains('Do you have any pets?'), true);
    });

    test('buildAnalysisPrompt and schema contains newLearnedUserFacts', () {
      final prompt = SystemPromptBuilder.buildAnalysisPrompt();
      expect(prompt.contains('EXTRAKCE NOVÝCH OSOBNÍCH FAKTŮ O STUDENTOVI ("O MNĚ")'), true);

      final schema = SystemPromptBuilder.getAnalysisResponseSchema();
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('newLearnedUserFacts'), true);
      expect((schema['required'] as List).contains('newLearnedUserFacts'), true);
    });

    test('buildTopicPreparationPrompt and schema is valid', () {
      final prompt = SystemPromptBuilder.buildTopicPreparationPrompt(
        targetLevel: 'B1',
        userFacts: '["Má psa"]',
        recentTopics: 'Filmy a kino',
        recentTranscriptsSnippet: 'Student: I watched Inception yesterday.\nTudor: Great movie!',
        memoryBriefing: 'Procvičit minulý čas',
      );

      expect(prompt.contains('PŘÍSNÝ ZÁKAZ OPAKOVANÝCH OTÁZEK NA ZNÁMÁ FAKTA'), true);
      expect(prompt.contains('ZÁKAZ BIZARNOSTÍ'), true);
      expect(prompt.contains('Má psa'), true);
      expect(prompt.contains('Filmy a kino'), true);
      expect(prompt.contains('Inception'), true);

      final schema = SystemPromptBuilder.getTopicPreparationResponseSchema();
      expect((schema['required'] as List).contains('topicTitle'), true);
      expect((schema['required'] as List).contains('openerEn'), true);
      expect((schema['required'] as List).contains('rationale'), true);
    });

    test('buildFactExtractionFromHistoryPrompt and schema is valid', () {
      final prompt = SystemPromptBuilder.buildFactExtractionFromHistoryPrompt();
      expect(prompt.contains('Domácí mazlíčky'), true);
      expect(prompt.contains('Koníčky a záliby'), true);

      final schema = SystemPromptBuilder.getFactExtractionSchema();
      expect((schema['required'] as List).contains('facts'), true);
    });
  });
}

