import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/widgets/chat_bubble.dart';
import 'package:aj_tudor/core/widgets/interactive_tutor_text.dart';
import 'package:aj_tudor/core/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ChatBubble Tests', () {
    testWidgets('renders user message on right with gradient and without tutor avatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ChatBubble(
            text: 'Hello, tutor!',
            isUser: true,
          ),
        ),
      );

      // Verify text
      expect(find.text('Hello, tutor!'), findsOneWidget);

      // Verify avatar is NOT present for user
      expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);

      // Verify alignment
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerRight);

      // Verify user bubble uses plain Text, not InteractiveTutorText
      expect(find.byType(InteractiveTutorText), findsNothing);
    });

    testWidgets('renders tutor message on left with robot avatar and InteractiveTutorText',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ChatBubble(
            text: 'Hello! **How** are you doing today?',
            isUser: false,
          ),
        ),
      );

      // Verify robot avatar is present
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);

      // Verify InteractiveTutorText is used for tutor messages
      expect(find.byType(InteractiveTutorText), findsOneWidget);

      // Verify alignment
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('calls onTap callback when user taps on user message',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: ChatBubble(
            text: 'Tap test',
            isUser: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Tap test'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('long press on user message copies text and shows SnackBar',
        (WidgetTester tester) async {
      // Mock clipboard
      String? clipboardData;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData = (methodCall.arguments as Map)['text'];
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const ChatBubble(
            text: 'Copy this message',
            isUser: true,
          ),
        ),
      );

      // Long press
      await tester.longPress(find.text('Copy this message'));
      await tester.pumpAndSettle();

      expect(clipboardData, 'Copy this message');
      expect(find.text('Zpráva zkopírována do schránky'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('respects maxWidthFraction constraints', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: const ChatBubble(
            text: 'Constraint test',
            isUser: true,
            maxWidthFraction: 0.50,
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(ChatBubble),
        matching: find.byType(Container),
      );

      final constrainedContainer = tester.widgetList<Container>(containerFinder).firstWhere(
            (c) => c.constraints?.maxWidth != null,
          );

      // Screen width is 800, fraction is 0.50 -> maxWidth = 400
      expect(constrainedContainer.constraints!.maxWidth, 400.0);
    });
  });
}

