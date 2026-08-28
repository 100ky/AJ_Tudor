# 🇬🇧 AJ Tudor – Konverzační AI Tutor angličtiny

**AJ Tudor** je pokročilá mobilní aplikace ve **Flutteru** pro výuku a procvičování konverzační angličtiny v reálném čase. Využívá **Google Gemini Multimodal Live API** (WebSocket Audio-to-Audio streamování) a multi-agentní architekturu pro přirozený, plynulý hlasový dialog bez znatelné latence.

---

## 🌟 Klíčové vlastnosti

- 🎙️ **Real-time hlasová konverzace (A2A)**: Obousměrný WebSocket přenos surového PCM audia přímo do modelu `gemini-3.1-flash-live-preview` (odezva pod 1 sekundu).
- 🤖 **Multi-agentní systém**:
  - **Voice Tutor Agent**: Řídí živý hlasový dialog, detekci řeči (VAD), skákání do řeči (barge-in), ochranu proti repetici a automatické popostrčení (nudge).
  - **Memory Manager Agent**: Po skončení lekce asynchronně analyzuje transkript pomocí *Structured Outputs (JSON)*, sleduje chyby, slovní zásobu a aplikuje Ebbinghausovu křivku zapomínání.
  - **Scenario Planner Agent**: Generuje a plánuje situační role-play scénáře (např. v restauraci, na letišti, pracovní pohovor).
- 🛠️ **Real-time Function Calling**: Tutor během mluvení na pozadí volá nástroj `log_error` pro telemetrii gramatických, slovníkových i výslovnostních chyb.
- 🎨 **Light Glassmorphism Design**: Moderní a čisté uživatelské rozhraní se skleněnými kartami (`BackdropFilter`), měkkými stíny a dynamickými gradientními bloby pro živý vzhled.
- 📊 **Sledování pokroku & Statistika**: Přehledné grafy (`fl_chart`), vývoj plynulosti (fluency score), historie lekcí a kartotéka chyb.
- 💾 **Lokální offline persistence**: Lokální SQLite databáze přes `Drift`, bezpečné ukládání API klíče přes `flutter_secure_storage`.

---

## 🏗️ Architektura a technologie

```
lib/
├── core/                  # Konstanty, utility, logování, barvy, témata
│   ├── constants/         # Názvy modelů Gemini, systémové konfigurace
│   └── utils/             # Logger, Result typy, pomocné funkce
├── data/                  # Datová vrstva (Drift ORM, SQLite databáze, modely, repozitáře)
│   ├── local/             # Databázové schéma Drift (AppDatabase)
│   ├── models/            # Datové modely (ChatMessage, Session, ErrorLog...)
│   └── repositories/      # Abstrakce a implementace repozitářů
├── features/              # UI obrazovky a komponenty rozdělené dle domény
│   ├── agents/            # Obrazovka správy agentů
│   ├── conversation/      # Hlavní hlasová obrazovka (mikrofon, waveform, živý chat)
│   ├── history/           # Historie proběhlých konverzací a jejich detail
│   ├── progress/          # Statistiky, grafy, přehled chyb a slovíček
│   ├── settings/          # Nastavení (Gemini API klíč, volba hlasu, modelů)
│   └── skeleton/          # Hlavní navigační shell (BottomNavigationBar)
├── providers/             # Riverpod providery pro správu stavu
└── services/              # Aplikační služby
    ├── agents/            # Notifiery pro VoiceTutorAgent, MemoryManagerAgent, ScenarioPlannerAgent
    ├── audio/             # Nahrávání mikrofonu (record) a přehrávání (flutter_pcm_sound)
    ├── gemini/            # WebSocket klient pro Gemini Live API
    ├── prompt/            # Dynamický konstruktor systémových promptů (SystemPromptBuilder)
    └── system/            # Wakelock (udržení zapnutého displeje), notifikace
```

### Použité balíčky (Dependencies)
- **State Management**: `flutter_riverpod`
- **Database & Storage**: `drift`, `sqlite3`, `flutter_secure_storage`, `shared_preferences`
- **Audio Pipeline**: `record` (PCM 16-bit 16kHz mono), `flutter_pcm_sound` (PCM 16-bit 24kHz mono)
- **Networking & AI**: `web_socket_channel` (Gemini Live WebSocket), `dio` (REST API pro analýzy)
- **UI & Grafy**: `fl_chart`, `google_fonts` (Plus Jakarta Sans), `wakelock_plus`

---

## 🚀 Jak aplikaci spustit

### 1. Požadavky
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12.2 nebo novější)
- Android Studio / VS Code s Flutter rozšířením
- Android zařízení (fyzické zařízení je doporučeno pro testování mikrofonu a zvuku)
- **Google Gemini API klíč** (z [Google AI Studio](https://aistudio.google.com/))

### 2. Instalace závislostí
```bash
flutter pub get
```

### 3. Generování kódu (Drift / JSON serialization)
Pokud měníte databázové entity nebo modely:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Spuštění aplikace
```bash
flutter run
```

### 5. Nastavení API klíče v aplikaci
Po prvním spuštění přejděte na záložku **Settings** (Nastavení) a vložte svůj **Gemini API klíč**. Následně můžete okamžitě zahájit hlasovou konverzaci.

---

## 🎙️ Jak funguje Gemini Live Audio Pipeline

1. **Vstup (Mikrofon)**: Aplikace snímá mikrofon na 16 000 Hz, 16-bit PCM Mono.
2. **Streaming do AI**: Každý audio blok je zakódován do Base64 a odeslán přes WebSocket ve formátu:
   ```json
   {
     "realtimeInput": {
       "audio": {
         "mimeType": "audio/pcm;rate=16000",
         "data": "<base64>"
       }
     }
   }
   ```
3. **Výstup z AI**: Model v reálném čase vrací 24 000 Hz PCM audio chunky a STT textový přepis.
4. **Lokální VAD & Nudge**: Pokud uživatel domluví, lokální Voice Activity Detection a záchranné časovače zajistí, že model okamžitě dostane signál k odpovědi (`turnComplete: true`).
