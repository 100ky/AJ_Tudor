import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late MockGeminiBatchClient mockGemini;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    mockGemini = MockGeminiBatchClient();

    container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repo),
        geminiBatchClientProvider.overrideWithValue(mockGemini),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('TopicPreparationAgent Tests', () {
    test('loads existing preparedTopic from database on build', () async {
      final initialTopic = PreparedTopic(
        title: 'Cestování po Skotsku',
        openerEn: 'Have you ever visited Scotland?',
        rationale: 'Zájem o přírodu',
        preparedAt: DateTime.now(),
      );
      await repo.updateUserMemory('Init');
      await repo.savePreparedTopic(jsonEncode(initialTopic.toJson()));

      // Read the provider and wait for the initial async microtask to complete
      container.read(topicPreparationAgentProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(topicPreparationAgentProvider);
      expect(state.topic, isNotNull);
      expect(state.topic?.title, 'Cestování po Skotsku');
      expect(state.topic?.openerEn, 'Have you ever visited Scotland?');
    });

    test('prepareTopic does nothing if geminiBatchClient is null', () async {
      final containerNoKey = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repo),
          geminiBatchClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(containerNoKey.dispose);

      final notifier = containerNoKey.read(topicPreparationAgentProvider.notifier);
      await notifier.prepareTopic(force: true);

      final state = containerNoKey.read(topicPreparationAgentProvider);
      expect(state.topic, isNull);
    });

    test('prepareTopic respects 12-hour freshness when force is false', () async {
      final freshTopic = PreparedTopic(
        title: 'Kavárny v Praze',
        openerEn: 'What is your favorite cafe in Prague?',
        rationale: 'Káva',
        preparedAt: DateTime.now().subtract(const Duration(hours: 2)), // 2 hours old < 12h
      );
      await repo.updateUserMemory('Init');
      await repo.savePreparedTopic(jsonEncode(freshTopic.toJson()));

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      // Force = false -> should NOT call Gemini
      await notifier.prepareTopic(force: false);

      verifyNever(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      ));

      expect(container.read(topicPreparationAgentProvider).topic?.title, 'Kavárny v Praze');
    });

    test('prepareTopic generates standard topic and updates database when forced', () async {
      await repo.updateUserMemory('Notes from last session');
      await repo.addUserFact('Pracuje jako programátor');

      final standardTopicResponse = jsonEncode({
        "topicTitle": "Nové technologie a AI",
        "openerEn": "Hey! Have you seen any interesting new tech recently?",
        "rationale": "Student se věnuje IT."
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      )).thenAnswer((_) async => standardTopicResponse);

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await notifier.prepareTopic(force: true);

      final state = container.read(topicPreparationAgentProvider);
      expect(state.topic, isNotNull);
      expect(state.topic?.title, 'Nové technologie a AI');
      expect(state.topic?.isRandomTopic, false);
      expect(state.refreshCount, 1);

      // Verify persisted to DB
      final savedJson = await repo.getPreparedTopic();
      expect(savedJson, isNotNull);
      expect(savedJson?.contains('Nové technologie a AI'), true);
    });

    test('prepareTopic triggers random wildcard topic when isRandomTopic is explicitly true', () async {
      await repo.updateUserMemory('Notes');

      final randomTopicResponse = jsonEncode({
        "topicTitle": "Cestování časem",
        "openerEn": "If you had a time machine, would you go to the future or the past?",
        "rationale": "Divoká karta na přání."
      });

      String? capturedPrompt;
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      )).thenAnswer((invocation) async {
        capturedPrompt = invocation.namedArguments[const Symbol('systemPrompt')] as String?;
        return randomTopicResponse;
      });

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await notifier.prepareTopic(force: true, isRandomTopic: true);

      final state = container.read(topicPreparationAgentProvider);
      expect(state.topic, isNotNull);
      expect(state.topic?.title, 'Cestování časem');
      expect(state.topic?.isRandomTopic, true);

      // Verify prompt was the wildcard random topic prompt
      expect(capturedPrompt?.contains('Divokou kartu / Wildcard'), true);
    });

    test('prepareTopic automatically triggers wildcard on every 3rd forced refresh', () async {
      await repo.updateUserMemory('Notes');

      final standardResp = jsonEncode({
        "topicTitle": "Běžné téma",
        "openerEn": "Tell me about your day.",
        "rationale": "Standard."
      });

      final wildcardResp = jsonEncode({
        "topicTitle": "Superschopnosti",
        "openerEn": "What superpower would you choose?",
        "rationale": "Divoká karta."
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      )).thenAnswer((invocation) async {
        final prompt = invocation.namedArguments[const Symbol('systemPrompt')] as String?;
        if (prompt != null && prompt.contains('Divokou kartu')) {
          return wildcardResp;
        }
        return standardResp;
      });

      final notifier = container.read(topicPreparationAgentProvider.notifier);

      // 1st forced refresh -> standard
      await notifier.prepareTopic(force: true);
      expect(container.read(topicPreparationAgentProvider).topic?.title, 'Běžné téma');
      expect(container.read(topicPreparationAgentProvider).topic?.isRandomTopic, false);

      // 2nd forced refresh -> standard
      await notifier.prepareTopic(force: true);
      expect(container.read(topicPreparationAgentProvider).topic?.title, 'Běžné téma');
      expect(container.read(topicPreparationAgentProvider).topic?.isRandomTopic, false);

      // 3rd forced refresh -> wildcard!
      await notifier.prepareTopic(force: true);
      expect(container.read(topicPreparationAgentProvider).topic?.title, 'Superschopnosti');
      expect(container.read(topicPreparationAgentProvider).topic?.isRandomTopic, true);
    });

    test('prepareTopic bootstraps user facts from transcript history if facts are empty', () async {
      await repo.updateUserMemory('Notes');
      // No user facts yet in profile

      // Insert past session with user messages
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(
        sessionId: s,
        speaker: 'user',
        content: 'I have a golden retriever named Buddy and I love hiking.',
      );

      final factsResponse = jsonEncode({
        "facts": ["Má psa Buddyho", "Rád chodí na túry"]
      });

      final topicResponse = jsonEncode({
        "topicTitle": "Turistika se psem",
        "openerEn": "Where do you like to hike with Buddy?",
        "rationale": "Navazuje na nově zjištěná fakta."
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      )).thenAnswer((invocation) async {
        final prompt = invocation.namedArguments[const Symbol('systemPrompt')] as String?;
        if (prompt != null && prompt.contains('analyzovat zprávy studenta z předchozích rozhovorů')) {
          return factsResponse;
        }
        return topicResponse;
      });

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await notifier.prepareTopic(force: true);

      // Verify facts were extracted and saved into profile
      final userFacts = await repo.getUserFacts();
      expect(userFacts.contains('Má psa Buddyho'), true);
      expect(userFacts.contains('Rád chodí na túry'), true);

      // Topic was prepared
      expect(container.read(topicPreparationAgentProvider).topic?.title, 'Turistika se psem');
    });

    test('consumeTopic clears topic from db and sets state.topic to null', () async {
      final topic = PreparedTopic(
        title: 'Dočasné téma',
        openerEn: 'Temporary topic',
        rationale: 'Test',
        preparedAt: DateTime.now(),
      );
      await repo.updateUserMemory('Init');
      await repo.savePreparedTopic(jsonEncode(topic.toJson()));

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(topicPreparationAgentProvider).topic, isNotNull);

      await notifier.consumeTopic();

      expect(container.read(topicPreparationAgentProvider).topic, isNull);
      expect(await repo.getPreparedTopic(), isNull);
    });

    test('resetRefreshCounter resets the refresh counter to zero', () async {
      await repo.updateUserMemory('Init');
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
        temperature: any(named: 'temperature'),
      )).thenAnswer((_) async => jsonEncode({
        "topicTitle": "Téma",
        "openerEn": "Opener",
        "rationale": "Reason"
      }));

      final notifier = container.read(topicPreparationAgentProvider.notifier);
      await notifier.prepareTopic(force: true);
      expect(notifier.refreshCount, 1);

      notifier.resetRefreshCounter();
      expect(notifier.refreshCount, 0);
    });
  });
}

