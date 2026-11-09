import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';
import 'package:aj_tudor/data/repositories/flashcard_repository.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';
import 'package:aj_tudor/services/agents/memory_manager_agent.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/system/wakelock_service.dart';

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

/// Zaznamená, kdo drží displej rozsvícený.
class _FakeWakelock implements WakelockService {
  final List<Object> holders = [];
  final List<Object> enabled = [];

  @override
  void enable([Object holder = 'hovor']) {
    holders.add(holder);
    enabled.add(holder);
  }

  @override
  void disable([Object holder = 'hovor']) => holders.remove(holder);
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late ProfileRepository profileRepo;
  late FlashcardRepository flashcardRepo;
  late MockGeminiBatchClient mockGemini;
  late MockScenarioPlannerAgent mockScenarioPlanner;
  late FakeTopicPreparationAgent fakeTopicAgent;
  late ProviderContainer container;

  late _FakeWakelock wakelock;

  setUp(() {
    wakelock = _FakeWakelock();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    profileRepo = ProfileRepository(db);
    flashcardRepo = FlashcardRepository(db);
    mockGemini = MockGeminiBatchClient();
    mockScenarioPlanner = MockScenarioPlannerAgent();
    fakeTopicAgent = FakeTopicPreparationAgent();

    when(() => mockScenarioPlanner.planScenarios()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(repo),
        databaseProvider.overrideWithValue(db),
        geminiAnalysisClientProvider.overrideWithValue(mockGemini),
        scenarioPlannerAgentProvider.overrideWithValue(mockScenarioPlanner),
        topicPreparationAgentProvider.overrideWith(() => fakeTopicAgent),
        wakelockServiceProvider.overrideWithValue(wakelock),
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
          databaseProvider.overrideWithValue(db),
          geminiAnalysisClientProvider.overrideWithValue(null),
          wakelockServiceProvider.overrideWithValue(wakelock),
        ],
      );
      addTearDown(containerNoKey.dispose);

      final agent = containerNoKey.read(memoryManagerAgentProvider);
      await agent.analyzeSession(1);

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt')));
    });

    test('analyzeSession exits early if session has empty transcripts', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      final agent = container.read(memoryManagerAgentProvider);

      await agent.analyzeSession(s);

      verifyNever(() => mockGemini.sendMessage(any(),
          responseSchema: any(named: 'responseSchema'),
          systemPrompt: any(named: 'systemPrompt')));
    });

    test('analyzeSession handles short session (<2 user messages) without overwriting memory briefing', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await profileRepo.updateUserMemory('Preserved initial briefing');

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
      final profile = await profileRepo.getUserProfile();
      expect(profile?.memoryBriefing, 'Preserved initial briefing');
    });

    test('analyzeSession fully processes normal session, updates db, extracts facts, creates flashcards, and prunes resolved errors', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await profileRepo.updateUserMemory('Initial long-term briefing');
      await profileRepo.updateUserRecurringErrors(['Past simple errors', 'Articles a/the']);

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
            "targetWordOrPhrase": "have been working",
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

      // 2. Krátká lekce (pár vět) o úrovni nic neříká, profil ji nemění
      final profile = await profileRepo.getUserProfile();
      expect(profile?.targetLevel, isNot('B2'));
      expect(sessions.first.estimatedLevel, isNull);

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
      final facts = await profileRepo.getUserFacts();
      expect(facts.contains('Pracuje jako softwarový inženýr'), true);
      expect(facts.contains('Rád pije espresso'), true);

      // 7. Flashcard created with Czech prompt on front and English on back
      final cards = await flashcardRepo.getAllFlashcards();
      expect(cards.length, 1);
      expect(cards.first.frontText, 'Pracuji jako softwarový inženýr již 5 let.');
      expect(cards.first.backText, 'have been working');
      expect(cards.first.sourceSentence, 'I have been working as a software engineer for 5 years.');
      expect(cards.first.errorType, 'grammar');

      // 8. ScenarioPlanner and TopicPreparation triggered
      verify(() => mockScenarioPlanner.planScenarios()).called(1);
      expect(fakeTopicAgent.prepareTopicCalls, 1);
      expect(fakeTopicAgent.lastForce, true);
      expect(fakeTopicAgent.lastResetCounter, true);
    });

    test('a long briefing keeps its beginning and the tutor critique has its own limit', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'First line');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Second line');

      // Dřív se nechávalo posledních 600 znaků: slabiny a téma na příště zmizely
      // a z paměti zbyla hlavně kritika tutora
      final longBriefing = 'Slabiny: minulý čas. ${'Další doporučení pro příště. ' * 30}';
      final mockJson = jsonEncode({
        "topicSummary": "Long briefing test",
        "fluencyScore": 0.7,
        "estimatedLevel": "B1",
        "totalErrors": 0,
        "briefing": longBriefing,
        "tutorFeedback": 'Neopravuj drobnosti. ' * 30,
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

      final profile = await profileRepo.getUserProfile();
      final parts = profile!.memoryBriefing!.split('\n\nKRITICKÁ SEBE-REFLEXE (Self-Correction pro tutora na příště): ');
      expect(parts, hasLength(2));
      expect(parts.first, startsWith('Slabiny: minulý čas.'));
      expect(parts.first, endsWith('příště.'));
      expect(parts.first.length, lessThanOrEqualTo(MemoryManagerAgent.maxBriefingChars));
      expect(parts.last, endsWith('drobnosti.'));
      expect(parts.last.length, lessThanOrEqualTo(MemoryManagerAgent.maxTutorFeedbackChars));
    });

    test('clipBriefing cuts after a sentence, or marks a cut inside one', () {
      expect(MemoryManagerAgent.clipBriefing('Krátké.', 600), 'Krátké.');
      expect(MemoryManagerAgent.clipBriefing('První věta. Druhá dlouhá věta', 20), 'První věta.');
      expect(MemoryManagerAgent.clipBriefing('A' * 30, 10), '${'A' * 10}…');
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

    test('a repeated analysis replaces the errors and unpractised cards of the previous one', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'I goed to the shop.');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Yesterday I see a film.');
      final oldError = (await repo.addErrorLog(
        sessionId: s, errorType: 'grammar', userSaid: 'I goed', correctForm: 'I went', explanation: 'x',
      )).getOrThrow();
      final practisedError = (await repo.addErrorLog(
        sessionId: s, errorType: 'grammar', userSaid: 'I see', correctForm: 'I saw', explanation: 'x',
      )).getOrThrow();
      final unpractised = (await flashcardRepo.addFlashcard(
        errorLogId: oldError, frontText: 'jít', backText: 'go', explanation: 'x',
      )).getOrThrow();
      final practised = (await flashcardRepo.addFlashcard(
        errorLogId: practisedError, frontText: 'vidět', backText: 'see', explanation: 'x',
      )).getOrThrow();
      await flashcardRepo.reviewFlashcard(flashcardId: practised, rating: 3);

      // 9. 11.: druhý rozbor lekce uložil chyby i kartičky podruhé
      final removed = await repo.clearSessionAnalysis(s);

      expect(removed, (errors: 2, cards: 1));
      expect(await repo.getErrorLogs(s), isEmpty);
      final cards = await db.select(db.flashcards).get();
      expect(cards.map((c) => c.id), [practised]);
      expect(cards.single.errorLogId, isNull);
      expect(cards.map((c) => c.id), isNot(contains(unpractised)));
    });

    test('a second analysis of a lesson that is being analyzed waits for the first one', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 1');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 2');
      final reply = Completer<String>();
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) => reply.future);
      final agent = container.read(memoryManagerAgentProvider);

      // 9. 11.: automatické opakování a ruční „Analyzovat“ ve stejnou chvíli
      final first = agent.analyzeSession(s);
      final second = agent.analyzeSession(s);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      reply.completeError(Exception('API Timeout'));

      expect(await first, isFalse);
      expect(await second, isFalse);
      verify(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).called(1);
    });

    test('the screen stays on during the analysis, also when it fails', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 1');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 2');
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenThrow(const GeminiNetworkException());

      await container.read(memoryManagerAgentProvider).analyzeSession(s);
      expect(wakelock.enabled, ['rozbor lekce $s']);
      expect(wakelock.holders, isEmpty);
    });

    test('an analysis without network waits for a retry, a finished one does not', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 1');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'User message 2');
      final agent = container.read(memoryManagerAgentProvider);

      // 9. 11.: displej zhasl hned po hovoru a systém aplikaci odpojil od sítě
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenThrow(const GeminiNetworkException());
      await agent.analyzeSession(s);
      expect(agent.analysesAwaitingNetwork, [s]);

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenThrow(Exception('API Timeout'));
      await agent.analyzeSession(s);
      expect(agent.analysesAwaitingNetwork, isEmpty);
    });

    test('analyzeSession creates atomic flashcard and filters out leaked tutor messages', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'What do you like doing in your free time?');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Running cleans my head.');
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'Zkus se prosím soustředit na naši anglickou konverzaci...');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Sorry, I got distracted.');

      final mockJson = jsonEncode({
        "topicSummary": "Běhání a konverzace",
        "fluencyScore": 0.8,
        "estimatedLevel": "B1",
        "totalErrors": 2,
        "briefing": "Zaměř se na idiomy",
        "resolvedErrors": [],
        "vocabulary": [],
        "newLearnedUserFacts": [],
        "errors": [
          // 1. Platná chyba s atomickou kartičkou
          {
            "type": "vocabulary",
            "userSaid": "Running cleans my head.",
            "targetWordOrPhrase": "clear one's head",
            "czechCue": "vyčistit si hlavu",
            "correctForm": "Running clears my head.",
            "explanation": "Správný anglický idiom je 'clear one's head', nikoliv 'clean'.",
            "czechTranslation": "vyčistit si hlavu"
          },
          // 2. Halucinace / leak tutorovy instrukce (musí být odfiltrována!)
          {
            "type": "grammar",
            "userSaid": "Zkus se prosím soustředit na naši anglickou konverzaci a nepřepínej do překládání úkolů.",
            "targetWordOrPhrase": "was at my father's house",
            "czechCue": "byl jsem u táty",
            "correctForm": "was at my father's house",
            "explanation": "Chyba",
            "czechTranslation": "byl jsem u táty"
          }
        ]
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockJson);

      final agent = container.read(memoryManagerAgentProvider);
      await agent.analyzeSession(s);

      final flashcards = await flashcardRepo.getAllFlashcards();
      // Musí být vytvořena pouze 1 kartička (leak tutorovy zprávy byl zahozen)
      expect(flashcards.length, 1);
      final card = flashcards.first;
      expect(card.frontText, 'vyčistit si hlavu');
      expect(card.backText, 'clear one\'s head');
      expect(card.sourceSentence, 'Running clears my head.');
      expect(card.explanation.contains("clear one's head"), true);
    });

    test('the level in the profile is the most common estimate of the last lessons', () {
      expect(MemoryManagerAgent.stableLevel(const []), isNull);
      expect(MemoryManagerAgent.stableLevel(['A2', 'B1', 'B1', 'A2', 'B1']), 'B1');
      // Při shodě platí novější odhad
      expect(MemoryManagerAgent.stableLevel(['A2', 'B1']), 'A2');
      expect(MemoryManagerAgent.countWords("I don't know, uh, třeba zítra."), 6);
    });

    test('the analysis stores the error category, the level and the words of the lesson', () async {
      // Dvě dřívější lekce s odhadem B1: jedna lekce s A2 úroveň v profilu nezmění.
      // Lekce s A1 a 40 slovy (skoro jen opakování) se nepočítá.
      for (final (level, words) in [('B1', 300), ('B1', 250), ('A1', 40)]) {
        final old = (await repo.startNewSession()).getOrThrow();
        await repo.updateSessionAnalysis(
            sessionId: old, topicSummary: 'Dřív', fluencyScore: 0.6, totalErrors: 0, estimatedLevel: level);
        await repo.updateSessionWordCounts(sessionId: old, studentWords: words, tutorWords: 200);
      }
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'What did you do yesterday at work?');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Yesterday I go to work.');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'I fix bug.');
      // Úroveň se odhaduje jen z lekce, kde student řekl aspoň 150 slov
      await repo.addTranscript(
          sessionId: s, speaker: 'user', content: List.filled(30, 'I worked on my app.').join(' '));

      final mockJson = jsonEncode({
        'topicSummary': 'Práce',
        'fluencyScore': 0.5,
        'estimatedLevel': 'A2',
        'levelDetail': 'A2+',
        'levelReason': 'Mluví srozumitelně, ale chybuje v minulém čase.',
        'totalErrors': 1,
        'briefing': '',
        'resolvedErrors': [],
        'vocabulary': [],
        'newLearnedUserFacts': [],
        'errors': [
          {
            'type': 'grammar',
            'category': 'tense',
            'userSaid': 'Yesterday I go to work.',
            'targetWordOrPhrase': 'went to work',
            'czechCue': 'šel jsem do práce',
            'correctForm': 'Yesterday I went to work.',
            'explanation': 'Minulý čas',
            'czechTranslation': 'šel jsem do práce',
          },
        ],
      });
      String? prompt;
      when(() => mockGemini.sendMessage(
            any(),
            responseSchema: any(named: 'responseSchema'),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenAnswer((invocation) async {
        prompt = invocation.namedArguments[#systemPrompt] as String;
        return mockJson;
      });

      await container.read(memoryManagerAgentProvider).analyzeSession(s);

      final session = (await repo.watchAllSessions().first).firstWhere((x) => x.id == s);
      expect(session.estimatedLevel, 'A2');
      expect(session.levelDetail, 'A2+');
      expect(session.levelReason, 'Mluví srozumitelně, ale chybuje v minulém čase.');
      expect(session.totalUserUtterances, 3);
      expect(session.studentWords, 158);
      expect(session.tutorWords, 7);
      expect((await profileRepo.getUserProfile())?.targetLevel, 'B1');
      expect((await repo.getErrorLogs(s)).single.category, 'tense');
      expect(prompt, contains('student řekl 96 % slov'));
    });

    test('one lesson makes at most six cards and none from a whole sentence', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'First line');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'Second line');

      Map<String, String> error(String target) => {
            'type': 'vocabulary',
            'userSaid': 'Jak se řekne $target?',
            'targetWordOrPhrase': target,
            'czechCue': 'cz $target',
            'correctForm': 'I said $target.',
            'explanation': 'Výraz z hovoru',
            'czechTranslation': 'cz $target',
          };
      final mockJson = jsonEncode({
        'topicSummary': 'Strop kartiček',
        'fluencyScore': 0.7,
        'estimatedLevel': 'B1',
        'totalErrors': 8,
        'briefing': '',
        'resolvedErrors': [],
        'vocabulary': [],
        'newLearnedUserFacts': [],
        'errors': [
          error('mashed potatoes'),
          // Celá věta místo výrazu: kartička nevznikne, chyba se ale zapíše
          error('to start things off what is your very first sentence'),
          for (final word in ['winterize', 'take a sick day', 'at least', 'take place', 'refill', 'harvest'])
            error(word),
        ],
      });
      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockJson);

      await container.read(memoryManagerAgentProvider).analyzeSession(s);

      final backs = (await flashcardRepo.getAllFlashcards()).map((c) => c.backText).toSet();
      expect(backs, {'mashed potatoes', 'winterize', 'take a sick day', 'at least', 'take place', 'refill'});
      expect(await repo.watchAllErrorLogs().first, hasLength(8));
    });

    test('analyzeSession skips errors whose transcript STT rendered in a foreign language', () async {
      final s = (await repo.startNewSession()).getOrThrow();
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'How has your week been?');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: '¿Mi semana fue muy buena, y la tuya?');
      await repo.addTranscript(sessionId: s, speaker: 'tutor', content: 'Glad to hear that! What did you do?');
      await repo.addTranscript(sessionId: s, speaker: 'user', content: 'मैंने बहुत काम किया');

      final mockJson = jsonEncode({
        "topicSummary": "Týden",
        "fluencyScore": 0.7,
        "estimatedLevel": "B1",
        "totalErrors": 2,
        "briefing": "",
        "resolvedErrors": [],
        "vocabulary": [],
        "newLearnedUserFacts": [],
        "errors": [
          {
            "type": "vocabulary",
            "userSaid": "¿Mi semana fue muy buena, y la tuya?",
            "targetWordOrPhrase": "my week was great",
            "czechCue": "můj týden byl skvělý",
            "correctForm": "My week was great, and yours?",
            "explanation": "Student přepnul do španělštiny.",
            "czechTranslation": "můj týden byl skvělý"
          },
          {
            "type": "vocabulary",
            "userSaid": "मैंने बहुत काम किया",
            "targetWordOrPhrase": "work a lot",
            "czechCue": "hodně pracovat",
            "correctForm": "I worked a lot.",
            "explanation": "Student přepnul do hindštiny.",
            "czechTranslation": "hodně pracovat"
          }
        ]
      });

      when(() => mockGemini.sendMessage(
        any(),
        responseSchema: any(named: 'responseSchema'),
        systemPrompt: any(named: 'systemPrompt'),
      )).thenAnswer((_) async => mockJson);

      final agent = container.read(memoryManagerAgentProvider);
      await agent.analyzeSession(s);

      expect(await flashcardRepo.getAllFlashcards(), isEmpty);
    });
  });
}

