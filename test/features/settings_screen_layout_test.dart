import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SettingsScreen voice and patience settings render with proper widths on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({
      'gemini_voice': 'Puck',
      'speech_silence_duration_ms': 1500,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Drag down to reveal voice settings
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 100));

    final voiceTitleFinder = find.text('Hlas učitele');
    final patienceTitleFinder = find.text('Trpělivost učitele (čas na rozmyšlenou)');

    expect(voiceTitleFinder, findsOneWidget);
    expect(patienceTitleFinder, findsOneWidget);

    final voiceRect = tester.getRect(voiceTitleFinder);
    final patienceRect = tester.getRect(patienceTitleFinder);

    // Title must not be squished down to 0 or single-letter width
    expect(voiceRect.width, greaterThan(80));
    expect(patienceRect.width, greaterThan(150));

    // And Dropdown selections are visible
    expect(find.text('Puck (Male)'), findsOneWidget);
    expect(find.text('Trpělivá (1 500 ms)'), findsOneWidget);
  });

  testWidgets('SettingsScreen voice settings render cleanly even on 320px screen', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({
      'gemini_voice': 'Aoede',
      'speech_silence_duration_ms': 2000,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Drag down to reveal voice settings
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 100));

    final voiceTitleFinder = find.text('Hlas učitele');
    final patienceTitleFinder = find.text('Trpělivost učitele (čas na rozmyšlenou)');

    expect(voiceTitleFinder, findsOneWidget);
    expect(patienceTitleFinder, findsOneWidget);

    final voiceRect = tester.getRect(voiceTitleFinder);
    final patienceRect = tester.getRect(patienceTitleFinder);

    // Ensure wide enough on 320px
    expect(voiceRect.width, greaterThan(80));
    expect(patienceRect.width, greaterThan(150));

    expect(find.text('Aoede (Female)'), findsOneWidget);
    expect(find.text('Extra trpělivá (2 000 ms)'), findsOneWidget);
  });
}

