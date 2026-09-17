import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/settings/settings_screen.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;
  late MockSecureStorage mockSecureStorage;
  late Map<String, String> secureMap;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockSecureStorage = MockSecureStorage();
    secureMap = {};
    when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((inv) async {
      return secureMap[inv.namedArguments[#key] as String];
    });
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((inv) async {
      secureMap[inv.namedArguments[#key] as String] = inv.namedArguments[#value] as String;
    });
    when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((inv) async {
      secureMap.remove(inv.namedArguments[#key] as String);
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(mockSecureStorage),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final mode = ref.watch(themeModeProvider);
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: const SettingsScreen(),
          );
        },
      ),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all sections and initial UI components',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // App bar title
      expect(find.text('Nastavení'), findsOneWidget);

      // Section labels
      expect(find.text('KONFIGURACE UMĚLÉ INTELIGENCE'), findsOneWidget);
      expect(find.text('VZHLED APLIKACE'), findsOneWidget);
      expect(find.text('UPOZORNĚNÍ A PŘIPOMÍNKY'), findsOneWidget);
      expect(find.text('HLASOVÉ A KONVERZAČNÍ NASTAVENÍ'), findsOneWidget);

      // Initial API key state (not set)
      expect(find.text('Není nastaven žádný klíč. Aplikace nebude fungovat.'), findsOneWidget);
      expect(find.text('Vložit API klíč'), findsOneWidget);

      // Appearance segment buttons
      expect(find.text('Světlý'), findsOneWidget);
      expect(find.text('Tmavý'), findsOneWidget);
      expect(find.text('Systém'), findsOneWidget);

      // Reminders switch
      expect(find.text('Denní připomínky'), findsOneWidget);

      // Smart bubbles switch
      expect(find.text('Chytré bubliny chatu'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('edits and saves Gemini API key', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Vložit API klíč'
      await tester.tap(find.text('Vložit API klíč'));
      await tester.pumpAndSettle();

      // Enter key into text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'AIzaSyTestKeyValid123');
      await tester.pump();

      // Tap 'Uložit'
      await tester.tap(find.text('Uložit'));
      await tester.pumpAndSettle();

      // Verify SnackBar
      expect(find.text('API klíč úspěšně uložen! ✅'), findsOneWidget);

      // Verify updated state in secure storage and UI
      expect(secureMap['gemini_api_key'], 'AIzaSyTestKeyValid123');
      expect(find.text('Klíč je uložen a připraven k použití.'), findsOneWidget);
      expect(find.text('Změnit API klíč'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('switches theme mode between light, dark and system',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Switch to Dark mode
      await tester.tap(find.text('Tmavý'));
      await tester.pumpAndSettle();

      expect(prefs.getString('app_theme_mode'), 'dark');

      // Switch to Light mode
      await tester.tap(find.text('Světlý'));
      await tester.pumpAndSettle();

      expect(prefs.getString('app_theme_mode'), 'light');

      // Switch to System mode
      await tester.tap(find.text('Systém'));
      await tester.pumpAndSettle();

      expect(prefs.getString('app_theme_mode'), 'system');

      await drainTimers(tester);
    });

    testWidgets('toggles reminders switch and reveals extra reminder settings',
        (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially time and annoying mode are not shown
      expect(find.text('Čas upozornění'), findsNothing);
      expect(find.text('Otravný režim 😈'), findsNothing);

      // Find switch for reminders and toggle it
      final remindersTile = find.widgetWithText(SwitchListTile, 'Denní připomínky');
      expect(remindersTile, findsOneWidget);

      await tester.tap(remindersTile);
      await tester.pumpAndSettle();

      // Now extra settings should appear
      expect(find.text('Čas upozornění'), findsOneWidget);
      expect(find.text('Otravný režim 😈'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('toggles smart bubbles configuration', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final smartBubblesTile = find.widgetWithText(SwitchListTile, 'Chytré bubliny chatu');
      expect(smartBubblesTile, findsOneWidget);

      // Default is true, tapping it toggles to false
      await tester.tap(smartBubblesTile);
      await tester.pumpAndSettle();

      expect(prefs.getBool('smart_bubbles_enabled'), isFalse);

      // Tap again to toggle back to true
      await tester.tap(smartBubblesTile);
      await tester.pumpAndSettle();

      expect(prefs.getBool('smart_bubbles_enabled'), isTrue);

      await drainTimers(tester);
    });
  });
}

