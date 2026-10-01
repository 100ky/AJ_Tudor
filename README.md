# 🇬🇧 AJ Tudor – Konverzační AI Tutor angličtiny

**AJ Tudor** je pokročilá mobilní aplikace ve **Flutteru** pro výuku a procvičování konverzační angličtiny v reálném čase. Využívá **Google Gemini Multimodal Live API** (WebSocket Audio-to-Audio streamování) a multi-agentní architekturu pro přirozený, plynulý hlasový dialog bez znatelné latence.

---

## 🌟 Klíčové vlastnosti

- 🎙️ **Real-time hlasová konverzace (A2A)**: Obousměrný WebSocket přenos surového PCM audia přímo do modelu `gemini-3.1-flash-live-preview` (odezva pod 1 sekundu).
- 🤖 **Multi-agentní systém**:
  - **Voice Tutor Agent**: Řídí živý hlasový dialog, detekci řeči (VAD), skákání do řeči (barge-in), ochranu proti repetici a automatické popostrčení (nudge).
  - **Memory Manager Agent**: Po skončení lekce asynchronně analyzuje transkript pomocí *Structured Outputs (JSON)*, sleduje chyby, slovní zásobu a aplikuje Ebbinghausovu křivku zapomínání.
- 📝 **Inteligentní telemetrie chyb & Memory Pruning**: Po skončení hovoru `MemoryManagerAgent` přes *Structured Outputs (JSON)* provede detailní rozbor chyb, extrahuje nová slovíčka, odnaučuje zvládnuté jevy a automaticky vytváří kartičky (Smart Flashcards) k procvičení.
- 📊 **Sledování pokroku & Statistika**: Přehledné grafy (`fl_chart`), vývoj plynulosti (fluency score), historie lekcí a kartotéka chyb.
- 💾 **Lokální offline persistence**: Lokální SQLite databáze přes `Drift`, bezpečné ukládání API klíče přes `flutter_secure_storage`.

---

## 🏗️ Architektura a technologie

```
lib/
├── main.dart, app.dart    # Vstupní bod a kořenový widget
├── core/                  # Sdílené jádro – nezávisí na žádné jiné části aplikace
│   ├── config/            # Nastavení aplikace a API klíč (Riverpod providery nad SharedPreferences)
│   ├── constants/         # Názvy modelů Gemini
│   ├── error/             # Typy chyb (Failure)
│   ├── utils/             # Logger, Result
│   ├── widgets/           # Obecné UI prvky design systému (GlassContainer)
│   └── app_theme.dart     # Barvy a témata
├── data/                  # Datová vrstva (Drift ORM, SQLite)
│   ├── database/          # Schéma Drift (AppDatabase, tabulky)
│   ├── models/            # Datové modely a SRS plánovač opakování kartiček
│   ├── repositories/      # Repozitáře: lekce, profil studenta, scénáře, kartičky
│   └── data_providers.dart  # Providery databáze, repozitářů a datových streamů
├── features/              # Obrazovky rozdělené dle domény (části obrazovek ve widgets/)
│   ├── agents/            # Přehled agentů
│   ├── conversation/      # Hlasový tutor, gramatický dril, chat bubliny, překlad slov
│   ├── flashcards/        # Smart Flashcards (SRS opakování, výslovnost)
│   ├── history/           # Historie lekcí a jejich detail
│   ├── progress/          # Statistiky, grafy, přehled chyb a slovíček
│   ├── settings/          # Nastavení (API klíč, hlas, modely, záloha)
│   └── skeleton/          # Navigační shell a provider aktivní záložky
└── services/              # Aplikační logika – každá služba má svůj provider ve stejném souboru/složce
    ├── agents/            # VoiceTutor, VoiceDirector, MemoryManager, ScenarioPlanner, TopicPreparation
    ├── audio/             # Nahrávání mikrofonu (record) a přehrávání (flutter_pcm_sound)
    ├── flashcards/        # Tvorba kartiček pomocí AI (z chyb, nová slovíčka, překlad zadání)
    ├── gemini/            # Gemini Live (WebSocket), společné REST jádro a služby (batch, TTS, výslovnost, překlad)
    ├── notifications/     # Lokální připomínky
    ├── prompt/            # Všechny prompty: SystemPromptBuilder (agenti) a TaskPrompts (krátké úlohy)
    └── system/            # Wakelock, záloha databáze
```

Závislosti vedou jedním směrem: `features → services → data → core`. Nižší vrstva nikdy neimportuje vyšší.

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

### 3. Generování kódu (Drift)
Pokud měníte databázové tabulky:
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
