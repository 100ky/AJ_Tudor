import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/features/conversation/conversation_screen.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/core/widgets/smart_chat_bubble.dart';
import 'package:aj_tudor/core/widgets/interactive_tutor_text.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';
import 'package:aj_tudor/providers/gemini_provider.dart';
import 'package:aj_tudor/providers/profile_provider.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}
class MockSessionRepository extends Mock implements SessionRepository {}
class MockGeminiTtsService extends Mock implements GeminiTtsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeminiBatchClient mockBatchClient;
  late MockSessionRepository mockRepo;
  late MockGeminiTtsService mockTts;
  late SharedPreferences prefs;

  setUp(() async {
    mockBatchClient = MockGeminiBatchClient();
    mockRepo = MockSessionRepository();
    mockTts = MockGeminiTtsService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
  });

  Widget buildTestWidget({
    bool hasClient = true,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        geminiBatchClientProvider.overrideWithValue(hasClient ? mockBatchClient : null),
        sessionRepositoryProvider.overrideWithValue(mockRepo),
        geminiTtsServiceProvider.overrideWithValue(mockTts),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const ConversationScreen(),
      ),
    );
  }

  group('ConversationScreen (Dril) Tests', () {
    testWidgets('renders empty state with drill starter card and input field', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gramatická cvičebna'), findsOneWidget);
      expect(find.text('Spustit gramatický dril'), findsOneWidget);
    });

    testWidgets('shows warning SnackBar when starting drill without API client', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(hasClient: false));
      await tester.pumpAndSettle();

      // Tap on Spustit gramatický dril button
      await tester.tap(find.text('Spustit gramatický dril'));
      await tester.pumpAndSettle();

      expect(find.text('Chybí API klíč! Nastavte ho v Settings.'), findsOneWidget);
    });

    testWidgets('starts drill and displays AI explanation and sentences to translate',
        (WidgetTester tester) async {
      final completer = Completer<String>();
      when(() => mockBatchClient.sendMessage(
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildTestWidget(hasClient: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spustit gramatický dril'));
      await tester.pump();

      // Loading indicator in chat list is displayed
      expect(find.text('Tutor vyhodnocuje a připravuje cvičení...'), findsOneWidget);

      completer.complete('Vysvětlení: Minulý čas prostý vyjadřuje ukončený děj v minulosti.\n1. Včera jsem šel do kina.');
      await tester.pumpAndSettle();

      // Verify AI response message is displayed via InteractiveTutorText
      expect(find.byType(InteractiveTutorText), findsOneWidget);
      expect(find.text('Vysvětlení:'), findsOneWidget);
      expect(find.byType(SmartChatBubble), findsNWidgets(2)); // User kickoff + Tutor response
    });

    testWidgets('sends user translation via text field and receives evaluation',
        (WidgetTester tester) async {
      when(() => mockBatchClient.sendMessage(
            any(),
            systemPrompt: any(named: 'systemPrompt'),
          )).thenAnswer(
        (_) async => 'Výborně! Yesterday I went to the cinema je správně!',
      );

      await tester.pumpWidget(buildTestWidget(hasClient: true));
      await tester.pumpAndSettle();

      // Enter text into input
      await tester.enterText(find.byType(TextField), 'Yesterday I went to the cinema');
      await tester.pump();

      // Tap send button
      final sendButton = find.byIcon(Icons.arrow_upward_rounded);
      expect(sendButton, findsOneWidget);

      await tester.tap(sendButton);
      await tester.pump();

      // User message is now in the list
      expect(find.text('Yesterday I went to the cinema'), findsOneWidget);

      await tester.pumpAndSettle();

      // AI evaluation is displayed with words parsed by InteractiveTutorText
      expect(find.byType(InteractiveTutorText), findsOneWidget);
      expect(find.text('Výborně!'), findsOneWidget);
      expect(find.text('správně!'), findsOneWidget);
    });
  });
}
