import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/services/agents/memory_manager_agent.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}
class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}

class FakeTopicPreparationAgent extends TopicPreparationAgent {
  int prepareTopicCalls = 0;
  bool? lastForce;
  bool? lastResetCounter;

  @override
  TopicPreparationState build() => const TopicPreparationState();

  @override
  Future<void> prepareTopic({
    bool force = false,
    bool resetCounter = false,
    bool? isRandomTopic,
  }) async {
    prepareTopicCalls++;
    lastForce = force;
    lastResetCounter = resetCounter;
  }
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late MockGeminiBatchClient mockGemini;
  late MockScenarioPlannerAgent mockScenarioPlanner;
  late FakeTopicPreparationAgent fakeTopicAgent;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    mockGemini = MockGeminiBatchClient();
    mockScenarioPlanner = MockScenarioPlannerAgent();
    fakeTopicAgent = FakeTopicPreparationAgent();

    when(() => mockScenarioPlanner.planScenarios()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repo),
        geminiAnalysisClientProvider.overrideWithValue(mockGemini),
        scenarioPlannerAgentProvider.overrideWithValue(mockScenarioPlanner),
        topicPreparationAgentProvider.overrideWith(() => fakeTopicAgent),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('MemoryManagerAgent Tests', () {
    test('analyzeSession does nothing when geminiAnalysisClient is null', () async {
      final containerNoKey = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repo),
          geminiAnalysisClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(containerNoKey.dispose);

      final agent = containerNoKey.read(memoryManagerAgentProvider);
      await agent.analyzeSession(1);

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt'),
          temperature: any(named: 'temperature')));
    });

    test('analyzeSession exits early if session has empty transcripts', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      final agent = container.read(memoryManagerAgentProvider);

      await agent.analyzeSession(s);

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt'),
          temperature: any(named: 'temperature')));
    });

    test('analyzeSession handles short session (<2 user messages) without overwriting memory briefing', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.updateUserMemory('Preserved initial briefing');

      // Only 1 user message -> too short
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'Hello!');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Hi');

      const mockResponse = '''{
        "topicSummary": "Brief greeting",
        "fluencyScore": 0.5,
        "estimatedLevel": "B1",
        "totalErrors": 0,
        "briefing": "Should not be saved",
        "tutorFeedback": "",
        "resolvedErrors": [],
        "vocabulary": [],
        "newLearnedUserFacts": [],
        "errors": []
      }''';

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockResponse);

      final agent = container.read(memoryManagerAgentProvider);
      await agent.analyzeSession(s);

      // Session analysis should still be updated
      final sessions = await repo.watchAllSessions().first;
      expect(sessions.first.topicSummary, 'Brief greeting');
      expect(sessions.first.fluencyScore, 0.5);

      // But memory briefing should NOT be overwritten because session was too short
      final profile = await repo.getUserProfile();
      expect(profile?.memoryBriefing, 'Preserved initial briefing');
    });

    test('analyzeSession fully processes normal session, updates db, extracts facts, creates flashcards, and prunes resolved errors', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.updateUserMemory('Initial long-term briefing');
      await repo.updateUserRecurringErrors(['Past simple errors', 'Articles a/the']);

      // 3 user messages and 2 tutor messages
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'Tell me about your job.');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'I am work as a software engineer for 5 years.');
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'That sounds interesting! What else?');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'I really like drinking espresso every morning.');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'I went yesterday to Brno by train.');

      final mockAnalysisJson = jsonEncode({
        "topicSummary": "Práce a každodenní rutina",
        "fluencyScore": 0.85,
        "estimatedLevel": "B2",
        "totalErrors": 1,
        "briefing": "Student byl velmi komunikativní a reagoval pohotově.",
        "tutorFeedback": "Mluv trochu pomaleji.",
        "resolvedErrors": ["Past simple"],
        "vocabulary": ["engineer", "espresso"],
        "newLearnedUserFacts": ["Pracuje jako softwarový inženýr", "Rád pije espresso"],
        "errors": [
          {
            "type": "grammar",
            "userSaid": "I am work as a software engineer for 5 years.",
            "correctForm": "I have been working as a software engineer for 5 years.",
            "explanation": "Předpřítomný průběhový čas vyjadřující děj trvající až do současnosti.",
            "czechTranslation": "Pracuji jako softwarový inženýr již 5 let."
          }
        ]
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockAnalysisJson);

      final agent = container.read(memoryManagerAgentProvider);
      await agent.analyzeSession(s);

      // 1. Session summary & fluency updated
      final sessions = await repo.watchAllSessions().first;
      expect(sessions.first.topicSummary, 'Práce a každodenní rutina');
      expect(sessions.first.fluencyScore, 0.85);
      expect(sessions.first.totalErrors, 1);

      // 2. Profile target level updated to B2
      final profile = await repo.getUserProfile();
      expect(profile?.targetLevel, 'B2');

      // 3. Memory briefing updated with tutorFeedback appended
      expect(profile?.memoryBriefing?.contains('Student byl velmi komunikativní'), true);
      expect(profile?.memoryBriefing?.contains('KRITICKÁ SEBE-REFLEXE'), true);
      expect(profile?.memoryBriefing?.contains('Mluv trochu pomaleji.'), true);

      // 4. Memory pruning removed "Past simple errors"
      final List<dynamic> recurring = jsonDecode(profile!.recurringErrors);
      expect(recurring.contains('Articles a/the'), true);
      expect(recurring.any((e) => e.toString().toLowerCase().contains('past simple')), false);

      // 5. Vocabulary updated
      final List<dynamic> vocab = jsonDecode(profile.vocabulary);
      expect(vocab.contains('engineer'), true);
      expect(vocab.contains('espresso'), true);

      // 6. User facts updated
      final facts = await repo.getUserFacts();
      expect(facts.contains('Pracuje jako softwarový inženýr'), true);
      expect(facts.contains('Rád pije espresso'), true);

      // 7. Flashcard created with Czech prompt on front and English on back
      final cards = await repo.getAllFlashcards();
      expect(cards.length, 1);
      expect(cards.first.frontText, 'Pracuji jako softwarový inženýr již 5 let.');
      expect(cards.first.backText, 'I have been working as a software engineer for 5 years.');
      expect(cards.first.errorType, 'grammar');

      // 8. ScenarioPlanner and TopicPreparation triggered
      verify(() => mockScenarioPlanner.planScenarios()).called(1);
      expect(fakeTopicAgent.prepareTopicCalls, 1);
      expect(fakeTopicAgent.lastForce, true);
      expect(fakeTopicAgent.lastResetCounter, true);
    });

    test('analyzeSession trims briefing if length exceeds 600 characters', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'First line');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Second line');

      final longBriefing = 'A' * 700;
      final mockJson = jsonEncode({
        "topicSummary": "Long briefing test",
        "fluencyScore": 0.7,
        "estimatedLevel": "B1",
        "totalErrors": 0,
        "briefing": longBriefing,
        "tutorFeedback": "",
        "resolvedErrors": [],
        "vocabulary": [],
        "newLearnedUserFacts": [],
        "errors": []
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockJson);

      final agent = container.read(memoryManagerAgentProvider);
      await agent.analyzeSession(s);

      final profile = await repo.getUserProfile();
      expect(profile?.memoryBriefing?.startsWith('...'), true);
      expect(profile?.memoryBriefing?.length, 603);
    });

    test('analyzeSession handles exception in Gemini call gracefully without throwing', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 1');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 2');

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenThrow(Exception('API Timeout'));

      final agent = container.read(memoryManagerAgentProvider);
      // Should not throw
      await expectLater(agent.analyzeSession(s), completes);
    });
  });
}

