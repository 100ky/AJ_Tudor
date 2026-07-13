# AJ Tudor – Hlasová aplikace pro výuku angličtiny s Gemini Live API

Implementační plán vychází z [Tudor_analyza.txt](file:///c:/Users/tosma/Desktop/Aj_Tudor/Tudor_analyza.txt) a definuje postupné kroky k vytvoření plně funkční Flutter aplikace pro Android.

---

## Rozhodnutí ✅

| Otázka | Rozhodnutí |
|--------|-----------|
| **Název aplikace** | AJ Tudor (zatím ponecháno) |
| **Cílová úroveň** | Dynamická detekce úrovně – aplikace sama rozpozná úroveň uživatele z konverzace |
| **Persona tutora** | Neutrální, přátelský tutor bez specifického jména |
| **Distribuce** | Osobní použití – žádný Google Play, zjednodušená architektura |
| **Offline režim** | Není potřeba – vše online |

> [!NOTE]
> **Dynamická detekce úrovně** bude řešena přes Memory Manager agenta – po prvních konverzacích analyzuje slovní zásobu, složitost vět a chybovost, a automaticky přizpůsobí obtížnost. Inspirace konceptem z analýzy (Teacher Mode / Immersive Mode), ale s vlastní originální implementací.

---

## Průběh Fáze 0 – Příprava prostředí 🔧

| Krok | Stav | Detail |
|------|------|--------|
| Flutter SDK | ✅ Hotovo | `Flutter 3.44.6 • Dart 3.12.2` v `C:\flutter` |
| Android Studio | ✅ Nainstalováno | Přes winget, verze 2026.1.1.10 |
| Android SDK | ✅ Hotovo | SDK 36.1.0, cmdline-tools nainstalovány |
| API klíč | ✅ Máš | Google AI Studio – Free Tier |
| VS Code / Antigravity | ✅ Funguje | Vývojové prostředí připraveno |
| Flutter projekt | ⏳ Čeká | Po dokončení SDK setup |

---

## Navrhovaná architektura

```mermaid
graph TB
    subgraph "Android Device"
        UI["UI Layer<br/>Flutter Widgets"]
        VM["State Management<br/>Riverpod / BLoC"]
        
        subgraph "Core Services"
            VT["Voice Tutor Agent<br/>Real-time konverzace"]
            MM["Memory Manager Agent<br/>Asynchronní analýza"]
            AS["Audio Service<br/>PCM 16kHz/24kHz"]
        end
        
        subgraph "Data Layer"
            DB["SQLite / Drift<br/>Sessions, Transcripts, UserProfile"]
        end
        
        subgraph "Network Layer"
            WS["WebSocket Client<br/>Gemini Live API"]
            REST["REST Client<br/>Gemini Flash API"]
        end
    end
    
    subgraph "Google Cloud"
        LIVE["Gemini 2.0 Flash<br/>Multimodal Live API"]
        BATCH["Gemini 2.5 Flash-Lite<br/>Batch Analysis"]
    end
    
    UI --> VM
    VM --> VT
    VM --> MM
    VT --> AS
    VT --> WS
    MM --> REST
    AS -->|"PCM 16kHz"| WS
    WS -->|"PCM 24kHz"| AS
    WS --> LIVE
    REST --> BATCH
    VT --> DB
    MM --> DB
```

---

## Technologický stack

| Vrstva | Technologie | Balíček / Verze | Důvod volby |
|--------|------------|-----------------|-------------|
| Framework | Flutter | `>=3.24` (stable) | Cross-platform, nativní výkon, Hot Reload |
| Jazyk | Dart | `>=3.5` | Typová bezpečnost, async/await, Streams |
| State Management | Riverpod | `flutter_riverpod` | Reaktivní, testovatelný, dependency injection |
| Databáze | SQLite | `drift` + `sqlite3_flutter_libs` | Typově bezpečný ORM, reaktivní streamy |
| Audio Capture | Mikrofon | `record` nebo `mic_stream` | Přímý přístup k PCM datům |
| Audio Playback | PCM přehrávání | `flutter_pcm_sound` | Surové PCM bufferování bez hlaviček |
| WebSocket | Gemini Live | `web_socket_channel` | Standardní Dart WebSocket klient |
| REST API | Gemini Batch | `google_generative_ai` | Oficiální Google SDK pro Dart |
| Networking | HTTP | `dio` | Interceptory, retry logika |
| Serialization | JSON | `json_annotation` + `json_serializable` | Code generation pro JSON modely |
| Code Gen | Build Runner | `build_runner` | Generování Drift tabulek, JSON serializace |

---

## Struktura projektu

```
AJ_Tudor/
├── android/                          # Android-specifická konfigurace
├── lib/
│   ├── main.dart                     # Entry point, inicializace app
│   ├── app.dart                      # MaterialApp, routing, theme
│   │
│   ├── core/                         # Sdílené utility a konfigurace
│   │   ├── constants/
│   │   │   ├── api_constants.dart    # Gemini API URLs, MIME typy
│   │   │   └── audio_constants.dart  # Sample rates (16kHz, 24kHz), formáty
│   │   ├── config/
│   │   │   └── app_config.dart       # API klíče, feature flags
│   │   ├── theme/
│   │   │   ├── app_theme.dart        # Dark/light theme, barvy
│   │   │   └── app_typography.dart   # Fonty (Inter/Outfit)
│   │   └── utils/
│   │       ├── audio_utils.dart      # PCM konverze, resampling
│   │       └── logger.dart           # Logování
│   │
│   ├── data/                         # Data layer
│   │   ├── database/
│   │   │   ├── app_database.dart     # Drift databáze, migrace
│   │   │   ├── tables/
│   │   │   │   ├── sessions.dart     # Tabulka Sessions
│   │   │   │   ├── transcripts.dart  # Tabulka Transcripts
│   │   │   │   └── user_profiles.dart # Tabulka UserProfile
│   │   │   └── daos/
│   │   │       ├── session_dao.dart
│   │   │       ├── transcript_dao.dart
│   │   │       └── user_profile_dao.dart
│   │   ├── models/
│   │   │   ├── error_log.dart        # Model pro logované chyby
│   │   │   ├── conversation_analysis.dart  # Výstup Memory Managera
│   │   │   └── tutor_context.dart    # Injektovaný kontext pro tutora
│   │   └── repositories/
│   │       ├── session_repository.dart
│   │       └── profile_repository.dart
│   │
│   ├── services/                     # Business logika & agenti
│   │   ├── audio/
│   │   │   ├── audio_capture_service.dart   # Mikrofon → PCM 16kHz stream
│   │   │   ├── audio_playback_service.dart  # PCM 24kHz → reproduktor
│   │   │   └── audio_buffer_manager.dart    # Ring buffer, anti-underrun
│   │   ├── gemini/
│   │   │   ├── gemini_live_client.dart      # WebSocket spojení, Live API
│   │   │   ├── gemini_batch_client.dart     # REST API pro batch analýzu
│   │   │   ├── session_manager.dart         # Session resumption, GoAway handling
│   │   │   └── function_calling.dart        # log_error & další tool definice
│   │   ├── agents/
│   │   │   ├── voice_tutor_agent.dart       # Primární real-time agent
│   │   │   └── memory_manager_agent.dart    # Sekundární async agent
│   │   └── prompt/
│   │       ├── system_prompt_builder.dart   # Dynamická injekce kontextu
│   │       └── prompt_templates.dart        # Šablony bilingvních promptů
│   │
│   ├── features/                     # UI features (per-screen)
│   │   ├── conversation/
│   │   │   ├── conversation_screen.dart     # Hlavní hlasová obrazovka
│   │   │   ├── widgets/
│   │   │   │   ├── ambient_orb.dart         # Pulzující sféra (stav AI)
│   │   │   │   ├── live_transcript.dart     # Dynamické titulky
│   │   │   │   ├── waveform_visualizer.dart # Vizualizace zvukových vln
│   │   │   │   └── mic_button.dart          # Tlačítko mikrofonu
│   │   │   └── providers/
│   │   │       └── conversation_provider.dart
│   │   ├── progress/
│   │   │   ├── progress_screen.dart         # Panel pokroku
│   │   │   ├── widgets/
│   │   │   │   ├── error_chart.dart         # Graf chyb v čase
│   │   │   │   ├── topic_history.dart       # Probraná témata
│   │   │   │   └── vocabulary_list.dart     # Seznam slovíček
│   │   │   └── providers/
│   │   │       └── progress_provider.dart
│   │   ├── history/
│   │   │   ├── history_screen.dart          # Historie konverzací
│   │   │   └── widgets/
│   │   │       └── session_card.dart
│   │   └── settings/
│   │       └── settings_screen.dart         # Nastavení (API klíč, tema)
│   │
│   └── providers/                    # Globální Riverpod providers
│       ├── database_provider.dart
│       ├── audio_provider.dart
│       └── gemini_provider.dart
│
├── test/                             # Unit & widget testy
├── assets/                           # Fonty, animace (Lottie/Rive)
├── pubspec.yaml                      # Závislosti
└── README.md                         # Dokumentace projektu
```

---

## Datový model (Drift tabulky)

```dart
// Sessions – evidence konverzací
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get fluencyScore => real().nullable()();       // 0.0 – 1.0
  IntColumn get totalUserUtterances => integer().withDefault(const Constant(0))();
  IntColumn get totalErrors => integer().withDefault(const Constant(0))();
  TextColumn get topicSummary => text().nullable()();        // AI-generated shrnutí
}

// Transcripts – přepisy promluv
class Transcripts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get speaker => text()();                        // 'user' | 'tutor'
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get correctedForm => text().nullable()();       // Opravená verze (pokud chyba)
}

// UserProfiles – profil uživatele
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withDefault(const Constant('Student'))();
  TextColumn get nativeLanguage => text().withDefault(const Constant('cs'))();
  TextColumn get targetLevel => text().withDefault(const Constant('B1'))();
  TextColumn get recurringErrors => text()();                // JSON array
  TextColumn get vocabulary => text()();                     // JSON array
  TextColumn get topicPreferences => text()();               // JSON array
  DateTimeColumn get lastSessionAt => dateTime().nullable()();
  IntColumn get totalSessions => integer().withDefault(const Constant(0))();
}

// ErrorLogs – detailní log chyb (z Function Calling)
class ErrorLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get errorType => text()();                      // 'grammar' | 'vocabulary' | 'pronunciation'
  TextColumn get userSaid => text()();
  TextColumn get correctForm => text()();
  TextColumn get explanation => text()();                    // České vysvětlení
  DateTimeColumn get timestamp => dateTime()();
}
```

---

## Fáze implementace

### Fáze 0 – Příprava prostředí 🔧
- [ ] Instalace Flutter SDK + Android SDK
- [ ] Konfigurace VS Code (rozšíření Flutter, Dart)
- [ ] Inicializace Flutter projektu v `AJ_Tudor/`
- [ ] Získání Google AI Studio API klíče
- [ ] Ověření funkčnosti na emulátoru / fyzickém zařízení

### Fáze 1: Core Architecture & Data Layer (Hotovo)
- **Cíl**: Nastavit projekt, Riverpod, Drift a základní routování.
- **Úkoly**:
  - [x] Inicializace Flutter (Riverpod, GoRouter/Navigator, Drift).
  - [x] Vytvoření Drift databáze a tabulek (`sessions`, `transcripts`, `error_logs`, `user_profile`).
  - [x] Základní Skeleton UI (Bottom Nav s 4 taby).

### Fáze 2: Gemini Integration (Probíhá)
- [ ] REST klient pro Gemini Flash API (`google_generative_ai`)
- [ ] System prompt builder s bilingvním prompt engineeringem
- [ ] Textový chat mód (jako fallback a pro testování)
- [ ] Function Calling definice (`log_error`)
- [ ] Structured Outputs pro Memory Manager

### Fáze 3 – Audio pipeline 🎤
- [ ] Audio capture service (mikrofon → PCM 16kHz mono)
- [ ] Audio playback service (PCM 24kHz → reproduktor)
- [ ] Buffer manager (ring buffer, anti-underrun)
- [ ] Testování audio pipeline izolovaně (echo test)

### Fáze 4 – Gemini Live API (hlasový mód) 🗣️
- [ ] WebSocket klient pro `wss://generativelanguage.googleapis.com`
- [ ] Binární PCM streaming (send & receive)
- [ ] Session manager (context compression, GoAway handling, session resumption)
- [ ] Integrace s audio pipeline
- [ ] Real-time transkripce z API

### Fáze 5 – Multi-agentní systém 🧠
- [ ] Memory Manager agent (post-session analýza)
- [ ] Dynamická injekce kontextu (memory-injected prompting)
- [ ] Error tracking přes Function Calling v reálném čase
- [ ] Aktualizace UserProfile po každé konverzaci

### Fáze 6 – Ambient UI & UX ✨
- [ ] Pulzující sféra / orb animace (stavy: idle, listening, thinking, speaking)
- [ ] Live transcript s blednutím slov
- [ ] Waveform vizualizace
- [ ] Progress dashboard (grafy chyb, témata, slovíčka)
- [ ] Historie konverzací s přehráváním

### Fáze 7 – Polish & Robustnost 🛡️
- [ ] Offline graceful degradation
- [ ] Síťová odolnost (retry, reconnect)
- [ ] Error handling & user-friendly chybové hlášky
- [ ] Optimalizace výkonu (audio latence, UI jank)
- [ ] Unit testy pro kritické komponenty
- [ ] README.md a dokumentace

---

## Proposed Changes

### [NEW] Flutter projekt

#### [NEW] `AJ_Tudor/` – Flutter project scaffold
- Inicializace přes `flutter create` s názvem `aj_tudor`
- Minimální Android SDK: 24 (Android 7.0)
- Kotlin jako Android jazyk

---

### Data Layer

#### [NEW] [app_database.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/data/database/app_database.dart)
- Drift databáze s 4 tabulkami, migrace, lazy inicializace

#### [NEW] [tables/](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/data/database/tables/)
- `sessions.dart`, `transcripts.dart`, `user_profiles.dart`, `error_logs.dart`

#### [NEW] [daos/](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/data/database/daos/)
- CRUD operace pro každou tabulku

---

### Services (Agents)

#### [NEW] [voice_tutor_agent.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart)
- Orchestrace audio capture → WebSocket → audio playback
- Zpracování Function Calling odpovědí (log_error)
- Bilingvní konverzační logika

#### [NEW] [memory_manager_agent.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/services/agents/memory_manager_agent.dart)
- Post-session analýza přes batch Gemini API
- Extrakce chyb, témat, slovíček do UserProfile
- Structured JSON output

#### [NEW] [gemini_live_client.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/services/gemini/gemini_live_client.dart)
- WebSocket spojení s Gemini Multimodal Live API
- PCM binární streaming
- Session resumption (handle ukládání, GoAway handling)

---

### UI Features

#### [NEW] [conversation_screen.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/features/conversation/conversation_screen.dart)
- Ambient Mode: centrální orb + live transcript + mic button
- Minimalistický, pohlcující design

#### [NEW] [progress_screen.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/AJ_Tudor/lib/features/progress/progress_screen.dart)
- Dashboard s grafy, seznamem chyb, slovíčky

---

## Verification Plan

### Automated Tests
```bash
flutter test                          # Unit & widget testy
flutter analyze                       # Static analysis
```

### Manual Verification
- **Fáze 0**: `flutter doctor` – vše zelené ✅
- **Fáze 1**: Ověření CRUD operací v databázi, navigace mezi obrazovkami
- **Fáze 2**: Textový chat s Gemini – ověření bilingvních odpovědí a Function Calling
- **Fáze 3**: Echo test – nahrávání a přehrávání PCM audia
- **Fáze 4**: Živá hlasová konverzace s Gemini Live API na fyzickém zařízení
- **Fáze 5**: Kontrola, že Memory Manager správně analyzuje konverzaci a aktualizuje profil
- **Fáze 6**: Vizuální kontrola animací, latence UI < 16ms (60fps)
- **Fáze 7**: Test odpojení sítě, obnovení session, stress test
