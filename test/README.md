# 🧪 Testovací sada AJ Tudor

Tato složka obsahuje komplexní sadu automatizovaných unit, widget a integračních testů pro aplikaci **AJ Tudor**.

---

## 📂 Struktura testů

```
test/
├── core/                                         # Testy jádra aplikace a utilit
│   ├── interactive_tutor_text_test.dart          # Výběr textu a extrakce frází
│   ├── result_test.dart                          # Typ Result<T> a zpracování chyb
│   └── widgets/                                  # Základní UI komponenty design systému
│       ├── glass_container_test.dart             # Skleněný kontejner (blur, specular bordery, margin)
│       ├── chat_bubble_test.dart                 # Konverzační bublina (uživatel vs tutor, clipboard)
│       ├── smart_chat_bubble_test.dart           # Chytrá bublina (kartička opravy, akordeon, TTS, uložení)
│       └── word_translation_sheet_test.dart      # Bottom sheet kontextového překladu a rozšiřování frází
├── data/                                         # Testy datové vrstvy a repozitářů
│   └── repositories/
│       └── session_repository_test.dart          # CRUD sessions, kaskádový delete, paměť, SRS, deduplikace
├── features/                                     # Testy obrazovek a modulů aplikace
│   ├── skeleton/
│   │   └── skeleton_screen_test.dart             # Hlavní shell, navigace (5 tabů), API klíč warning
│   ├── conversation/
│   │   ├── conversation_screen_test.dart         # Gramatická cvičebna a interaktivní dril
│   │   ├── voice_tutor_screen_test.dart          # Hlasový tutor (režimy, transkript, volání, audio)
│   │   └── widgets/
│   │       └── fluid_voice_wave_test.dart        # Vykreslování audio křivky (waveform, plynulé animace)
│   ├── history/
│   │   └── history_screen_test.dart              # Historie lekcí, filtry, detail lekce, mazání
│   ├── agents/
│   │   └── agents_screen_test.dart               # Multi-agentní přehled, generování scénářů na míru
│   ├── progress/
│   │   └── progress_screen_test.dart             # Přehled pokroku, grafy (plynulost, chyby), paměť, statistiky
│   ├── flashcards/
│   │   └── flashcards_screen_test.dart           # Cvičebna kartiček, 3D otočení, SRS hodnocení, TTS
│   ├── settings/
│   │   └── settings_screen_test.dart             # Nastavení API klíče, motivy, připomínky, chytré bubliny
│   ├── flashcards_test.dart                      # Integrační test logiky kartiček
│   ├── settings_screen_layout_test.dart          # Responzivita a prvky v nastavení
│   └── user_facts_and_topics_test.dart           # Správa faktů a témat uživatele
├── services/                                     # Testy aplikačních služeb a agentů
│   ├── agents/
│   │   ├── memory_manager_agent_test.dart        # Analýza session, Structured Outputs, memory pruning, fakta
│   │   ├── scenario_planner_agent_test.dart      # Plánování scénářů, integrace slabých kartiček, custom scénáře
│   │   ├── topic_preparation_agent_test.dart     # Příprava témat, 12h čerstvost, wildcard, facts bootstrap
│   │   └── voice_tutor_agent_test.dart           # Stavový automat tutora, VAD, reconnect, nudge
│   ├── prompt/
│   │   └── system_prompt_builder_test.dart       # Sestavování promptů (tutor, CEFR, drill, schémata, fakta)
│   ├── system/
│   │   └── backup_service_test.dart              # Validace SQLite hlavičky, export/import zálohy databáze
│   ├── gemini_tts_service_test.dart              # Gemini TTS, audio cache
│   ├── pronunciation_service_test.dart           # Analýza výslovnosti
│   └── translation_service_test.dart             # Překladový servis a disková cache
├── widget_test.dart                              # Základní smoke test
└── README.md                                     # Tento průvodce testováním
```

---

## 🚀 Jak spouštět testy

### 1. Spuštění všech testů
```bash
flutter test
```

### 2. Spuštění konkrétní skupiny testů
```bash
# Pouze testy základních UI widgetů
flutter test test/core/widgets/

# Pouze testy obrazovek a funkcí (features)
flutter test test/features/

# Pouze testy datové vrstvy a repozitáře
flutter test test/data/

# Pouze testy služeb a agentů
flutter test test/services/

# Pouze testy jádra (core)
flutter test test/core/
```

### 3. Spuštění konkrétního testovacího souboru
```bash
# Obrazovky
flutter test test/features/conversation/voice_tutor_screen_test.dart
flutter test test/features/history/history_screen_test.dart
flutter test test/features/agents/agents_screen_test.dart
flutter test test/features/progress/progress_screen_test.dart
flutter test test/features/flashcards/flashcards_screen_test.dart
flutter test test/features/settings/settings_screen_test.dart

# Repozitáře a backend logika
flutter test test/data/repositories/session_repository_test.dart
flutter test test/services/agents/memory_manager_agent_test.dart
flutter test test/services/agents/scenario_planner_agent_test.dart
flutter test test/services/agents/topic_preparation_agent_test.dart
flutter test test/services/prompt/system_prompt_builder_test.dart
flutter test test/services/system/backup_service_test.dart
```

### 4. Spuštění testů s generováním coverage reportu
```bash
flutter test --coverage
```
Report se vygeneruje do `coverage/lcov.info`. Pro vizualizaci v HTML lze použít nástroj `genhtml`:
```bash
genhtml coverage/lcov.info -o coverage/html
```

---

## 🛠️ Použité testovací knihovny a postupy

- **`flutter_test`**: Oficiální testovací framework Flutteru pro unit a widget testy.
- **`mocktail`**: Typově bezpečný mocking framework bez nutnosti generování kódu (`build_runner`).
- **`flutter_riverpod`**: Pro testování providerů s `ProviderScope` overrides.
- **`drift/native.dart`**: In-memory SQLite (`NativeDatabase.memory()`) pro reálné a deterministické testy databáze bez mockování dotazů.
- **Nekonečné animace (Repeating Tickers)**:
  - Komponenty jako `FluidVoiceWave` nebo obrazovky s blikajícím kurzorem mají opakující se tickery (`.repeat()`).
  - V těchto testech se **nepoužívá** `tester.pumpAndSettle()`, nýbrž časově omezené pumpování `await tester.pump(const Duration(milliseconds: 300))`.
- **Vyprázdnění Drift časovačů (`drainTimers`)**:
  - Drift plánuje makro-timer při uzavření streamů. Na konci testů je strom odpojen a vyprázdněn pomocí `drainTimers(tester)`.

---

## ✍️ Šablona pro psaní nových testů

Při psaní nového widget testu s Riverpodem a Driftem postupujte podle tohoto vzoru:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/app_theme.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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

  Widget buildTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sessionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  testWidgets('renders component successfully', (WidgetTester tester) async {
    configureViewport(tester);
    await tester.pumpWidget(buildTestWidget(child: const MyWidget()));
    await tester.pumpAndSettle();

    expect(find.byType(MyWidget), findsOneWidget);

    await drainTimers(tester);
  });
}
```
