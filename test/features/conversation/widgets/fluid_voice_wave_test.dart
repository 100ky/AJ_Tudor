import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/conversation/widgets/fluid_voice_wave.dart';

void main() {
  group('FluidVoiceWave Widget Tests', () {
    testWidgets('renders CustomPaint with specified height and default properties',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.blue,
              stateLabel: 'idle',
              height: 60,
            ),
          ),
        ),
      );

      // We use timed pump because FluidVoiceWave contains continuous repeating animation controllers
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FluidVoiceWave), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 60,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });

    testWidgets('animates across time intervals without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.teal,
              stateLabel: 'listening',
              height: 54,
              isCompact: true,
            ),
          ),
        ),
      );

      // Step through several animation ticks
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('reacts to incoming volumeStream updates',
        (WidgetTester tester) async {
      final volumeController = StreamController<double>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              volumeStream: volumeController.stream,
              color: Colors.purple,
              stateLabel: 'speaking',
              height: 80,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Emit volume spikes
      volumeController.add(0.4);
      await tester.pump(const Duration(milliseconds: 50));

      volumeController.add(0.85);
      await tester.pump(const Duration(milliseconds: 50));

      volumeController.add(0.1);
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);

      await volumeController.close();
    });

    testWidgets('handles stateLabel and color change on didUpdateWidget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.green,
              stateLabel: 'idle',
              height: 54,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Update to 'thinking' state with amber color
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.amber,
              stateLabel: 'thinking',
              height: 54,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes cleanly when unmounted',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.red,
              stateLabel: 'listening',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Unmount the widget completely
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    });
  });
}
