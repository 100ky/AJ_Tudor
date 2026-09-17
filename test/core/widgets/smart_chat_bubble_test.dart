import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/core/widgets/smart_chat_bubble.dart';
import 'package:aj_tudor/core/widgets/interactive_tutor_text.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/core/utils/result.dart';
import 'package:aj_tudor/data/models/chat_message.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';

class MockGeminiTtsService extends Mock implements GeminiTtsService {}
class MockSessionRepository extends Mock implements SessionRepository {}
class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeminiTtsService mockTts;
  late MockSessionRepository mockRepo;
  late MockGeminiBatchClient mockBatchClient;

  setUp(() {
    mockTts = MockGeminiTtsService();
    mockRepo = MockSessionRepository();
    mockBatchClient = MockGeminiBatchClient();

    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
  });

  Widget buildTestWidget({
    required ChatMessage message,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      overrides: [
        geminiTtsServiceProvider.overrideWithValue(mockTts),
        sessionRepositoryProvider.overrideWithValue(mockRepo),
        geminiBatchClientProvider.overrideWithValue(mockBatchClient),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SmartChatBubble(
              message: message,
            ),
          ),
        ),
      ),
    );
  }

  group('SmartChatBubble Tests', () {
    testWidgets('renders user message without corrections simply', (WidgetTester tester) async {
      final msg = ChatMessage(
        'I like learning English',
        isUser: true,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(message: msg));

      expect(find.text('I like learning English'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
      expect(find.text('Proč? Zobrazit pravidlo...'), findsNothing);
    });

    testWidgets('renders tutor message with robot avatar and TTS button', (WidgetTester tester) async {
      final msg = ChatMessage(
        'Great job! Keep it up.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(message: msg));

      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
      expect(find.byType(InteractiveTutorText), findsOneWidget);

      final ttsButton = find.byTooltip('Přehrát zprávu');
      expect(ttsButton, findsOneWidget);

      await tester.tap(ttsButton);
      await tester.pump();

      verify(() => mockTts.speak('Great job! Keep it up.')).called(1);
    });

    testWidgets('displays error card when user message has corrections', (WidgetTester tester) async {
      final msg = ChatMessage(
        'I goes to school yesterday.',
        isUser: true,
        timestamp: DateTime.now(),
        correctedSentence: 'I went to school yesterday.',
        corrections: [
          const ChatMessageCorrection(
            userSaid: 'I goes',
            correctForm: 'I went',
            explanation: 'V minulém čase se u slovesa go používá tvar went.',
            errorType: 'Past Tense',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message: msg));

      // Check original and corrected texts in the card
      expect(find.text('I goes'), findsOneWidget);
      expect(find.text('I went'), findsOneWidget);
      expect(find.text('Proč? Zobrazit pravidlo...'), findsOneWidget);

      // Tap to expand explanation
      await tester.tap(find.text('Proč? Zobrazit pravidlo...'));
      await tester.pumpAndSettle();

      expect(find.text('V minulém čase se u slovesa go používá tvar went.'), findsOneWidget);
    });

    testWidgets('plays TTS when user taps pronunciation button in correction card',
        (WidgetTester tester) async {
      final msg = ChatMessage(
        'She don\'t know.',
        isUser: true,
        timestamp: DateTime.now(),
        correctedSentence: 'She doesn\'t know.',
        corrections: [
          const ChatMessageCorrection(
            userSaid: 'don\'t',
            correctForm: 'doesn\'t',
            explanation: '3. osoba jednotného čísla vyžaduje doesn\'t.',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message: msg));

      final pronButton = find.text('Výslovnost');
      expect(pronButton, findsOneWidget);

      await tester.tap(pronButton);
      await tester.pump();

      verify(() => mockTts.speak('She doesn\'t know.')).called(1);
    });

    testWidgets('saves correction to flashcards when "Do kartiček" is tapped',
        (WidgetTester tester) async {
      when(() => mockBatchClient.sendMessage(any())).thenAnswer(
        (_) async => 'Ona neví.',
      );

      when(() => mockRepo.addFlashcard(
            frontText: any(named: 'frontText'),
            backText: any(named: 'backText'),
            explanation: any(named: 'explanation'),
            errorType: any(named: 'errorType'),
            sourceSentence: any(named: 'sourceSentence'),
          )).thenAnswer((_) async => const Result.success(1));

      final msg = ChatMessage(
        'She don\'t know.',
        isUser: true,
        timestamp: DateTime.now(),
        corrections: [
          const ChatMessageCorrection(
            userSaid: 'don\'t',
            correctForm: 'doesn\'t',
            explanation: '3. osoba jednotného čísla vyžaduje doesn\'t.',
            errorType: 'grammar',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message: msg));

      final flashcardsButton = find.text('Do kartiček');
      expect(flashcardsButton, findsOneWidget);

      await tester.tap(flashcardsButton);
      await tester.pumpAndSettle();

      // Verify repo was called
      verify(() => mockRepo.addFlashcard(
            frontText: 'Ona neví.',
            backText: 'doesn\'t',
            explanation: '3. osoba jednotného čísla vyžaduje doesn\'t.',
            errorType: 'grammar',
            sourceSentence: 'She don\'t know.',
          )).called(1);

      // Verify button transitioned to "V kartičkách"
      expect(find.text('V kartičkách'), findsOneWidget);
      expect(find.text('Uloženo do Smart Flashcards! 🃏'), findsOneWidget);
    });
  });
}

