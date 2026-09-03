import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/features/conversation/widgets/fluid_voice_wave.dart';

void main() {
  group('FluidVoiceWave Tests', () {
    testWidgets('renders in hero mode (isCompact: false)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.green,
              stateLabel: 'idle',
              height: 105,
              isCompact: false,
            ),
          ),
        ),
      );

      expect(find.byType(FluidVoiceWave), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders in compact mode (isCompact: true)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.cyan,
              stateLabel: 'speaking',
              height: 56,
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.byType(FluidVoiceWave), findsOneWidget);
    });

    testWidgets('renders thinking state with pulse sweep', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.purple,
              stateLabel: 'thinking',
              height: 56,
              isCompact: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FluidVoiceWave), findsOneWidget);
    });

    testWidgets('updates dynamically on volumeStream events', (tester) async {
      final volumeController = StreamController<double>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluidVoiceWave(
              color: Colors.green,
              stateLabel: 'listening',
              volumeStream: volumeController.stream,
              height: 56,
              isCompact: true,
            ),
          ),
        ),
      );

      volumeController.add(0.8);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FluidVoiceWave), findsOneWidget);

      await volumeController.close();
    });

    testWidgets('WaveStateIcon renders correct icons for states',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WaveStateIcon(stateLabel: 'listening', color: Colors.green),
                WaveStateIcon(stateLabel: 'thinking', color: Colors.purple),
                WaveStateIcon(stateLabel: 'speaking', color: Colors.blue),
                WaveStateIcon(stateLabel: 'idle', color: Colors.grey),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.hearing_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });
  });
}

