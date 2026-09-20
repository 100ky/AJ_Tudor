import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
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

  group('ScenarioPlannerAgent Tests', () {
    test('planScenarios exits early if profile is null', () async {
      final agent = container.read(scenarioPlannerAgentProvider);
      await agent.planScenarios();

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt')));
    });

    test('planScenarios exits early if geminiBatchClient is null', () async {
      await repo.updateUserMemory('Some briefing');
      final containerNoKey = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repo),
          geminiBatchClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(containerNoKey.dispose);

      final agent = containerNoKey.read(scenarioPlannerAgentProvider);
      await agent.planScenarios();

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt')));
    });

    test('planScenarios incorporates struggling flashcards (<0.6 mastery) and replaces scenarios', () async {
      await repo.updateUserMemory('Context briefing');
      await repo.updateTargetLevel('B1');

      // Add a struggling flashcard (masteryScore default is 0.0 < 0.6)
      await repo.addFlashcard(
        frontText: 'Těším se na tebe',
        backText: 'I look forward to seeing you',
        explanation: 'Look forward to + -ing',
      );

      // Add a mastered flashcard (masteryScore >= 0.6)
      final masteredCard = await repo.addFlashcard(
        frontText: 'Kočka',
        backText: 'Cat',
        explanation: 'Zvíře',
      );
      await repo.reviewFlashcard(flashcardId: masteredCard.getOrThrow(), rating: 3); // mastery >= 0.85

      final mockScenariosResponse = jsonEncode({
        "scenarios": [
          {
            "id": "scenario_coffee_shop",
            "title": "V kavárně v Londýně",
            "description": "Objednej si flat white a koláč.",
            "tutorInstruction": "Act as a busy London barista.",
            "difficulty": "easy"
          },
          {
            "id": "scenario_job_interview",
            "title": "Pracovní pohovor",
            "description": "Představ své silné stránky v IT.",
            "tutorInstruction": "Act as an HR director interviewing for a tech position.",
            "difficulty": "hard"
          },
          {
            "id": "scenario_hotel_checkin",
            "title": "Check-in v hotelu",
            "description": "Nahlás rezervaci na 3 noci.",
            "tutorInstruction": "Act as a friendly hotel receptionist.",
            "difficulty": "medium"
          }
        ]
      });

      String? capturedPrompt;
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((invocation) async {
        capturedPrompt = invocation.namedArguments[const Symbol('systemPrompt')] as String?;
        return mockScenariosResponse;
      });

      final agent = container.read(scenarioPlannerAgentProvider);
      await agent.planScenarios();

      // Verify prompt includes the struggling flashcard problem
      expect(capturedPrompt, isNotNull);
      expect(capturedPrompt?.contains('I look forward to seeing you'), true);
      // But does NOT include the mastered card
      expect(capturedPrompt?.contains('Problémy z kartiček: Kočka (Správně: Cat)'), false);

      // Verify scenarios are saved in DB
      final available = await repo.watchAvailableScenarios().first;
      expect(available.length, 3);
      expect(available.any((s) => s.title == 'V kavárně v Londýně'), true);
      expect(available.any((s) => s.title == 'Pracovní pohovor'), true);
      expect(available.any((s) => s.title == 'Check-in v hotelu'), true);
    });

    test('planCustomScenario generates and inserts custom scenario based on user hint', () async {
      await repo.updateUserMemory('Context');
      await repo.updateTargetLevel('A2');

      final customMockResponse = jsonEncode({
        "scenarios": [
          {
            "id": "custom_pizza",
            "title": "Objednávka pizzy v Neapoli",
            "description": "Zavolej do italské pizzerie a objednej si pizzu Margherita.",
            "tutorInstruction": "Act as an Italian pizzeria receptionist speaking English.",
            "difficulty": "medium"
          }
        ]
      });

      String? capturedSystemPrompt;
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((invocation) async {
        capturedSystemPrompt = invocation.namedArguments[const Symbol('systemPrompt')] as String?;
        return customMockResponse;
      });

      final agent = container.read(scenarioPlannerAgentProvider);
      final created = await agent.planCustomScenario('Objednávka pizzy');

      expect(created, isNotNull);
      expect(created?.title, 'Objednávka pizzy v Neapoli');
      expect(created?.difficulty, 'medium');
      expect(created?.isUsed, false);

      expect(capturedSystemPrompt?.contains('Objednávka pizzy'), true);
      expect(capturedSystemPrompt?.contains('A2'), true);

      // Verify it is present in available scenarios
      final available = await repo.watchAvailableScenarios().first;
      expect(available.any((s) => s.id == created?.id), true);
    });

    test('planCustomScenario returns null when client is missing or call fails', () async {
      final containerNoKey = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repo),
          geminiBatchClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(containerNoKey.dispose);

      final agentNoKey = containerNoKey.read(scenarioPlannerAgentProvider);
      final resNull = await agentNoKey.planCustomScenario('Anything');
      expect(resNull, isNull);

      // Failing Gemini call
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenThrow(Exception('Network error'));

      final agent = container.read(scenarioPlannerAgentProvider);
      final resError = await agent.planCustomScenario('Valid hint');
      expect(resError, isNull);
    });
  });
}

