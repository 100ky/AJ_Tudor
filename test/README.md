# 🧪 Testovací sada AJ Tudor

Tato složka obsahuje komplexní sadu automatizovaných unit, widget a integračních testů pro aplikaci **AJ Tudor**.

---

## 📂 Struktura testů

```
test/
├── core/                                         # Testy jádra aplikace a utilit
│   ├── result_test.dart                          # Typ Result<T> a zpracování chyb
│   └── widgets/
│       └── glass_container_test.dart             # Skleněný kontejner (blur, specular bordery, margin)
├── data/                                         # Testy datové vrstvy a repozitářů
│   ├── models/
│   │   ├── chat_message_test.dart                # ChatMessage a opravy pro chytré bubliny
│   │   └── srs_scheduler_test.dart               # SRS plánovač (intervaly, mastery, meze)
│   └── repositories/
│       ├── session_repository_test.dart          # Lekce, transkripty, chyby, kaskádový delete
│       ├── profile_repository_test.dart          # Paměť, slovní zásoba, chyby, fakta „O mně“, připravené téma
│       ├── scenario_repository_test.dart         # Scénáře (náhrada, vlastní scénář, použití)
│       └── flashcard_repository_test.dart        # Kartičky: duplicity, SRS hodnocení, statistiky, heuristiky
├── features/                                     # Testy obrazovek a modulů aplikace
│   ├── skeleton/
│   │   └── skeleton_screen_test.dart             # Hlavní shell, navigace (5 tabů), API klíč warning
│   ├── conversation/
│   │   ├── conversation_screen_test.dart         # Gramatická cvičebna a interaktivní dril
│   │   ├── grammar_drill_controller_test.dart    # Controller drilu (výběr chyb, start, odeslání, reset)
│   │   ├── voice_tutor_screen_test.dart          # Hlasový tutor (režimy, transkript, volání, audio)
│   │   └── widgets/
│   │       ├── fluid_voice_wave_test.dart        # Vykreslování audio křivky (waveform, plynulé animace)
│   │       ├── chat_bubble_test.dart             # Konverzační bublina (uživatel vs tutor, clipboard)
│   │       ├── smart_chat_bubble_test.dart       # Chytrá bublina (kartička opravy, akordeon, TTS, uložení)
│   │       ├── interactive_tutor_text_test.dart  # Výběr textu a extrakce frází
│   │       └── word_translation_sheet_test.dart  # Bottom sheet kontextového překladu a rozšiřování frází
│   ├── history/
│   │   ├── history_screen_test.dart              # Historie lekcí, filtry, detail lekce, mazání
│   │   └── session_detail_controller_test.dart   # Chat nad lekcí (kontext posledních 10 replik), mazání lekce
│   ├── agents/
│   │   └── agents_screen_test.dart               # Multi-agentní přehled, generování scénářů na míru
│   ├── progress/
│   │   └── progress_screen_test.dart             # Přehled pokroku, grafy (plynulost, chyby), paměť, statistiky
│   ├── flashcards/
│   │   ├── flashcards_screen_test.dart           # Cvičebna kartiček, 3D otočení, SRS hodnocení, TTS
│   │   ├── review_session_test.dart              # Průběh opakování (pořadí, počítadla, odebrání karty)
│   │   └── card_front_resolver_test.dart         # Česká zadání karet a překlad starých zadání
│   └── settings/
│       ├── settings_screen_test.dart             # Nastavení API klíče, motivy, připomínky, chytré bubliny
│       └── settings_screen_layout_test.dart      # Responzivita a prvky v nastavení
├── services/                                     # Testy aplikačních služeb a agentů
│   ├── agents/
│   │   ├── memory_manager_agent_test.dart        # Analýza session, Structured Outputs, memory pruning, fakta
│   │   ├── scenario_planner_agent_test.dart      # Plánování scénářů, integrace slabých kartiček, custom scénáře
│   │   ├── topic_preparation_agent_test.dart     # Příprava témat, 12h čerstvost, wildcard, facts bootstrap
│   │   ├── voice_director_agent_test.dart        # Režisér konverzace (cooldown, tipy, briefing pro reconnect)
│   │   ├── voice_tutor_agent_test.dart           # Stavový automat tutora, VAD, reconnect, nudge
│   │   └── voice_tutor/
│   │       ├── speech_activity_detector_test.dart # Detekce řeči (prahy, hystereze, adaptace na šum)
│   │       ├── tutor_text_analysis_test.dart     # Čištění přepisu, počet slov, opakování tutora
│   │       └── tutor_timers_test.dart            # Časovače tutora (spuštění, zrušení, cancelAll)
│   ├── flashcards/
│   │   └── flashcard_generation_service_test.dart # Kartičky z chyb, migrace starých zadání, nová slovíčka
│   ├── gemini/
│   │   └── gemini_rest_core_test.dart            # Pořadí modelů, cooldown, třídění chyb, dekódování JSON
│   ├── prompt/
│   │   ├── live_tutor_prompts_test.dart          # Pokyny během hovoru (úvodní zpráva, skryté instrukce)
│   │   ├── system_prompt_builder_test.dart       # Sestavování promptů (tutor, CEFR, drill, schémata, fakta)
│   │   ├── task_prompts_test.dart                # Krátké úlohové prompty (překlad, výslovnost, TTS, dril)
│   │   └── user_facts_and_topic_prompts_test.dart # Prompty s fakty „O mně“ a příprava témat
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
# Pouze testy chatových widgetů (bubliny, překlad slov)
flutter test test/features/conversation/widgets/

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
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/data/data_providers.dart';

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
