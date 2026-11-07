import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/services/agents/voice_director_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/data/repositories/profile_repository.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/services/flashcards/conversation_cards.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}
class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockGeminiBatchClient mockDirectorClient;
  late MockProfileRepository mockRepo;

  setUp(() {
    mockDirectorClient = MockGeminiBatchClient();
    mockRepo = MockProfileRepository();

    when(() => mockRepo.addUserFact(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        geminiDirectorClientProvider.overrideWithValue(mockDirectorClient),
        profileRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('VoiceDirectorAgent Tests', () {
    test('initial state has default values', () {
      final state = container.read(voiceDirectorAgentProvider);
      expect(state.isAnalyzing, false);
      expect(state.currentTip, isNull);
      expect(state.rollingSummary, isEmpty);
      expect(state.sessionFacts, isEmpty);
      expect(state.lastAnalyzedTurnIndex, 0);
      expect(state.lastHealthScore, 10);
    });

    test('reset clears state and dismissTip clears tip', () {
      final notifier = container.read(voiceDirectorAgentProvider.notifier);

      // Mutate state for testing
      notifier.state = notifier.state.copyWith(
        currentTip: 'Ask about pets',
        rollingSummary: 'Some summary',
        sessionFacts: ['Fact 1'],
        lastHealthScore: 4,
      );

      expect(container.read(voiceDirectorAgentProvider).currentTip, 'Ask about pets');

      notifier.dismissTip();
      expect(container.read(voiceDirectorAgentProvider).currentTip, isNull);

      notifier.reset();
      final resetState = container.read(voiceDirectorAgentProvider);
      expect(resetState.currentTip, isNull);
      expect(resetState.rollingSummary, isEmpty);
      expect(resetState.sessionFacts, isEmpty);
      expect(resetState.lastHealthScore, 10);
    });

    test('getExecutiveBriefingForReconnect formats structured briefing with rolling summary and facts', () {
      final notifier = container.read(voiceDirectorAgentProvider.notifier);

      notifier.state = notifier.state.copyWith(
        rollingSummary: 'Student discussed vacation in Scotland and rainy weather.',
        sessionFacts: ['Has a dog named Max', 'Works as a backend developer'],
      );

      final recentMessages = [
        ChatMessage('I really enjoy hiking in the Highlands.', isUser: true),
        ChatMessage('The Highlands are breathtaking! Did you reach Ben Nevis?', isUser: false),
      ];

      final briefing = notifier.getExecutiveBriefingForReconnect(
        recentMessages: recentMessages,
      );

      expect(briefing.contains('[SESSION CONTEXT RECOVERY - EXECUTIVE LIVING BRIEFING]'), true);
      expect(briefing.contains('Scotland and rainy weather'), true);
      expect(briefing.contains('Has a dog named Max; Works as a backend developer'), true);
      expect(briefing.contains('Student: I really enjoy hiking in the Highlands.'), true);
      expect(briefing.contains('AJ Tudor: The Highlands are breathtaking!'), true);
      expect(briefing.contains('CRITICAL INSTRUCTION: Continue conversation seamlessly'), true);
    });

    test('onTurnCompleted skips execution when unanalyzed user turns are less than threshold', () async {
      final notifier = container.read(voiceDirectorAgentProvider.notifier);

      final messages = [
        ChatMessage('Hello', isUser: true),
        ChatMessage('Hi there!', isUser: false),
        ChatMessage('How are you?', isUser: true),
        ChatMessage('I am great!', isUser: false),
      ]; // Only 2 user messages (threshold is 3)

      var whisperCalled = false;
      await notifier.onTurnCompleted(
        sessionId: 1,
        messages: messages,
        targetLevel: 'B1',
        userFacts: null,
        recentTopics: null,
        onWhisperReady: (_, _) => whisperCalled = true,
      );

      expect(whisperCalled, false);
      verifyNever(() => mockDirectorClient.sendMessage(
        any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'),
      ));
    });

    test('onTurnCompleted executes analysis, triggers whisper, updates rolling summary and facts', () async {
      final notifier = container.read(voiceDirectorAgentProvider.notifier);

      final messages = [
        ChatMessage('Hello!', isUser: true),
        ChatMessage('Hi! What did you do today?', isUser: false),
        ChatMessage('I went cycling in the park.', isUser: true),
        ChatMessage('Cycling is lovely. How far was it?', isUser: false),
        ChatMessage('About 15 kilometers, my legs are tired.', isUser: true),
        ChatMessage('Haha, that sounds like good exercise!', isUser: false),
      ]; // 3 user messages

      final mockResponse = jsonEncode({
        'topicHealth': 7,
        'needsPivot': false,
        'whisperToTutor': 'Ask what bicycle model they ride or if they commute by bike.',
        'studentHint': 'Ask Tudor: Do you ride a bike in Prague?',
        'newLearnedFacts': ['Rád jezdí na kole (15km)'],
        'incrementalSummary': 'Student went for a 15km bike ride in the park.',
      });

      when(() => mockDirectorClient.sendMessage(
        any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'),
      )).thenAnswer((_) async => mockResponse);

      String? deliveredWhisper;
      await notifier.onTurnCompleted(
        sessionId: 42,
        messages: messages,
        targetLevel: 'B1',
        userFacts: '["Student lives in Prague"]',
        recentTopics: '["Sports"]',
        onWhisperReady: (whisper, _) => deliveredWhisper = whisper,
      );

      // Verify whisper was delivered to tutor
      expect(deliveredWhisper, 'Ask what bicycle model they ride or if they commute by bike.');

      // Fakta ukládá do profilu jen rozbor po lekci, režisér si je drží jen pro tento hovor
      verifyNever(() => mockRepo.addUserFact(any()));

      // Verify state was updated
      final state = container.read(voiceDirectorAgentProvider);
      expect(state.lastHealthScore, 7);
      expect(state.currentTip, 'Ask Tudor: Do you ride a bike in Prague?');
      expect(state.rollingSummary, 'Student went for a 15km bike ride in the park.');
      expect(state.sessionFacts.contains('Rád jezdí na kole (15km)'), true);
      expect(state.lastAnalyzedTurnIndex, messages.length);
      expect(state.isAnalyzing, false);
    });

    group('flashcards', () {
      final card = ConversationCard(id: 7, czech: 'vzít si volno', english: 'take a sick day');
      final messages = [
        ChatMessage('I work a lot.', isUser: true),
        ChatMessage('Do you rest enough?', isUser: false),
        ChatMessage('Not really.', isUser: true),
        ChatMessage('I see.', isUser: false),
        ChatMessage('I am tired today.', isUser: true),
        ChatMessage('Oh no!', isUser: false),
      ];

      Future<(String?, ConversationCard?)> analyse(Map<String, Object?> output) async {
        when(() => mockDirectorClient.sendMessage(
              any(),
              systemPrompt: any(named: 'systemPrompt'),
              responseSchema: any(named: 'responseSchema'),
            )).thenAnswer((_) async => jsonEncode({
              'topicHealth': 7,
              'needsPivot': false,
              'studentHint': '',
              'newLearnedFacts': [],
              'incrementalSummary': '',
              ...output,
            }));
        final notifier = container.read(voiceDirectorAgentProvider.notifier)..reset();
        String? whisper;
        ConversationCard? woven;
        await notifier.onTurnCompleted(
          sessionId: 1,
          messages: messages,
          targetLevel: 'B1',
          userFacts: null,
          recentTopics: null,
          cards: [card],
          onWhisperReady: (w, c) {
            whisper = w;
            woven = c;
          },
        );
        return (whisper, woven);
      }

      test('the cards go into the prompt and the woven one comes with the whisper', () async {
        final (whisper, woven) = await analyse({
          'whisperToTutor': 'Ask what he does when he feels ill on a workday.',
          'flashcardId': 7,
        });
        expect(whisper, 'Ask what he does when he feels ill on a workday.');
        expect(woven?.id, 7);

        final prompt = verify(() => mockDirectorClient.sendMessage(
              any(),
              systemPrompt: captureAny(named: 'systemPrompt'),
              responseSchema: any(named: 'responseSchema'),
            )).captured.single as String;
        expect(prompt, contains('#7: vzít si volno → take a sick day'));
      });

      test('a card the director did not offer, or one without a whisper, weaves nothing', () async {
        var (whisper, woven) = await analyse({'whisperToTutor': 'Ask about his week.', 'flashcardId': 99});
        expect(whisper, 'Ask about his week.');
        expect(woven, isNull);

        (whisper, woven) = await analyse({'whisperToTutor': '', 'flashcardId': 7});
        expect(woven, isNull);
      });

      test('a whisper that says the phrase itself still weaves the card', () async {
        // Tutor dostane pokyn, ať výraz neřekne první; zopakování po něm kartičku nesplní
        final (_, woven) = await analyse({
          'whisperToTutor': 'Ask whether he would take a sick day.',
          'flashcardId': 7,
        });
        expect(woven?.id, 7);
      });

      test('a hint that gives the phrase away is not shown', () async {
        await analyse({
          'whisperToTutor': 'Ask what he does when he feels ill on a workday.',
          'studentHint': 'Say: I will take a sick day.',
          'flashcardId': 7,
        });
        expect(container.read(voiceDirectorAgentProvider).currentTip, isNull);
      });
    });

    test('onTurnCompleted handles API error gracefully without crashing', () async {
      final notifier = container.read(voiceDirectorAgentProvider.notifier);

      final messages = [
        ChatMessage('One', isUser: true),
        ChatMessage('One reply', isUser: false),
        ChatMessage('Two', isUser: true),
        ChatMessage('Two reply', isUser: false),
        ChatMessage('Three', isUser: true),
        ChatMessage('Three reply', isUser: false),
      ];

      when(() => mockDirectorClient.sendMessage(
        any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'),
      )).thenThrow(Exception('API connection timeout'));

      var whisperCalled = false;
      await notifier.onTurnCompleted(
        sessionId: 42,
        messages: messages,
        targetLevel: 'B1',
        userFacts: null,
        recentTopics: null,
        onWhisperReady: (_, _) => whisperCalled = true,
      );

      expect(whisperCalled, false);
      expect(container.read(voiceDirectorAgentProvider).isAnalyzing, false);
    });
  });
}

