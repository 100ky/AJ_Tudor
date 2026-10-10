import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/features/conversation/widgets/drill/drill_input_bar.dart';

void main() {
  testWidgets('thinking bubble wraps its text on a narrow phone instead of overflowing',
      (tester) async {
    // Šířka telefonu 360 dp, seznam drilu má okraje 16 dp
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: const [DrillThinkingBubble()],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tutor vyhodnocuje a připravuje cvičení...'), findsOneWidget);
  });
}
