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
├── features/              # Obrazovky dle domény: obrazovka skládá layout, části jsou ve widgets/, akce v *_controller.dart
│   ├── agents/            # Přehled agentů
│   ├── conversation/      # Hlasový tutor, gramatický dril (GrammarDrillController), chat bubliny, překlad slov
│   ├── flashcards/        # Smart Flashcards: FlashcardsController, průběh opakování (ReviewSession), výslovnost
│   ├── history/           # Historie lekcí a detail lekce (SessionDetailController)
│   ├── progress/          # Statistiky, grafy, přehled chyb a slovíček
│   ├── settings/          # Nastavení (API klíč, hlas, modely, záloha) a ProfileSettingsController
│   └── skeleton/          # Navigační shell a provider aktivní záložky
└── services/              # Aplikační logika – každá služba má svůj provider ve stejném souboru/složce
    ├── agents/            # VoiceTutor, VoiceDirector, MemoryManager, ScenarioPlanner, TopicPreparation
    │   └── voice_tutor/   # Části hlasového tutora: detekce řeči (VAD), časovače, metriky, analýza přepisu
    ├── audio/             # Nahrávání mikrofonu (record) a přehrávání (flutter_pcm_sound)
    ├── flashcards/        # Tvorba kartiček pomocí AI (z chyb, z oprav v chatu, nová slovíčka, překlad zadání)
    ├── gemini/            # Gemini Live (WebSocket), společné REST jádro a služby (batch, TTS, výslovnost, překlad)
    ├── notifications/     # Lokální připomínky
    ├── prompt/            # Všechny prompty: SystemPromptBuilder (agenti), LiveTutorPrompts (pokyny během hovoru), TaskPrompts (krátké úlohy)
    └── system/            # Wakelock, záloha databáze
```

### Pravidla struktury
- Závislosti vedou jedním směrem: `features → services → data → core`. Nižší vrstva nikdy neimportuje vyšší.
- Widgety nevolají AI ani nezapisují do databáze přímo. Jde to přes controller ve složce obrazovky, přes službu nebo přes agenta. Data z databáze čtou přes `StreamProvider`y v `data/data_providers.dart`.
- Soubor obrazovky jen skládá layout. Větší části patří do `widgets/`, akce do `*_controller.dart`.
- Provider služby leží ve stejném souboru nebo složce jako služba. Providery databáze, repozitářů a datových streamů jsou v `data/data_providers.dart`.
- Texty promptů jsou jen v `services/prompt/`.
- Volání Gemini REST API jdou přes `GeminiRestCore` (`services/gemini/gemini_rest_core.dart`). Jádro střídá modely, dává přetížené modely na cooldown a třídí chyby. Vlastní `Dio` jinde nevytvářejte.
- Soubor v `lib/` by neměl mít víc než zhruba 600 řádků. Výjimkou je generovaný `app_database.g.dart` a `system_prompt_builder.dart`.

### Použité balíčky (Dependencies)
- **State Management**: `flutter_riverpod`
- **Database & Storage**: `drift`, `sqlite3`, `flutter_secure_storage`, `shared_preferences`
- **Audio Pipeline**: `record` (PCM 16-bit 16kHz mono), `flutter_pcm_sound` (PCM 16-bit 24kHz mono)
- **Networking & AI**: `web_socket_channel` (Gemini Live WebSocket), `dio` (REST API pro analýzy)
- **UI & Grafy**: `fl_chart`, `google_fonts` (Plus Jakarta Sans), `wakelock_plus`

---

## 🚀 Jak aplikaci spustit

### 1. Požadavky
- [Flutter SDK](https://docs.flutter.dev/get-started/install) s Dartem 3.12.2 nebo novějším (ověřeno na Flutteru 3.47.5 s Dartem 3.13.4)
- Android Studio / VS Code s Flutter rozšířením. V Android Studiu nastavte cestu k Flutter SDK (např. `C:\flutter`) v *Settings → Languages & Frameworks → Flutter*.
- Android zařízení (fyzické zařízení je doporučeno pro testování mikrofonu a zvuku)
- **Google Gemini API klíč** (z [Google AI Studio](https://aistudio.google.com/))
- Na Windows potřebují pluginy symbolické odkazy. Když Flutter ohlásí „Building with plugins requires symlink support“, zapněte Režim pro vývojáře (*Nastavení → Systém → Pro vývojáře*).

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

---

## 🧪 Kontrola změn

Před každým commitem spusťte:

```bash
dart analyze lib test   # statická analýza
flutter test            # všechny testy, podrobnosti v test/README.md
```

Na cestě s diakritikou (např. `D:\Programování\…`) `flutter analyze` padá na chybě `FormatException`. `dart analyze` provede stejnou kontrolu a funguje.

Směr závislostí ověříte v Git Bash. Žádný z příkazů nesmí nic vypsat:

```bash
grep -rnE "import '.*(services|data|features)/" lib/core   # core neimportuje nic z aplikace
grep -rnE "import '.*(services|features)/" lib/data        # data neimportuje services ani features
grep -rn "features/" lib/services                          # services neimportuje features
```

Největší soubory (hranice je zhruba 600 řádků):

```bash
find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | sort -rn | head
```

### Ruční test na zařízení
Automatické testy nepokryjí mikrofon, přehrávání zvuku ani skutečné volání Gemini. Po větších změnách projděte na telefonu:

- [ ] Hlasová lekce: start, pauza a obnovení (i přes překlad slova), stop
- [ ] Překlad slova a uložení do kartiček
- [ ] Tlačítko „Do kartiček“ u opravy v chatové bublině
- [ ] Opakování kartiček, výslovnost a přehrání nahlas
- [ ] Chat nad lekcí (detail lekce v záložce Pokrok) a gramatický dril
- [ ] Nastavení: přepínače, úroveň angličtiny, přidání a smazání faktu „O mně“
- [ ] Záloha a import
- [ ] Reset paměti, jen pokud vám nevadí přijít o to, co si Tudor pamatuje

---

## 📋 Refaktoring struktury (říjen 2026)

Refaktoring proběhl ve větvi `refactor/structure` ve čtyřech fázích. Schéma databáze ani migrace se neměnily. Počet testů vzrostl z 210 na 321.

- **A, úklid:** z gitu zmizely `.artifacts/`, `.idea/` a dočasné soubory, z `pubspec.yaml` 4 nepoužívané balíčky. Složka `lib/providers/` zanikla a každý provider leží u své třídy.
- **B, Gemini:** čtyři REST služby (batch, TTS, výslovnost, překlad) sdílí `GeminiRestCore`. Všechny prompty jsou v `services/prompt/`.
- **C, databáze:** `SessionRepository` (1360 řádků) je rozdělený na repozitáře lekcí, profilu, scénářů a kartiček. Tvorbu kartiček přes AI dělá `FlashcardGenerationService`.
- **D, obrazovky:** logika obrazovek je v controllerech a části obrazovek ve `widgets/`. Z `VoiceTutorAgent` se vyčlenila detekce řeči, časovače, metriky, analýza přepisu a pokyny během hovoru.

### Změny chování
- **Opravená ztráta kartiček:** deduplikace kartiček při startu aplikace mazala všechny kartičky kromě jedné. Chyba je v kódu od 17. 9. 2026 a je i v `main`. Teď se z kartiček se stejnou anglickou stranou ponechá ta nejlépe naučená a ostatní kartičky zůstanou.
- HTTP 500 od Gemini se všude bere jako přetížení a zkusí se další model. Dřív to platilo jen u překladu.
- Překlad a výslovnost po odmítnutém API klíči (401/403) už nezkoušejí další modely. Uživatel vidí stejnou chybu jako dřív, jen odpadnou zbytečné požadavky.
- Mezi kartičkami k opakování se objeví i ty, které začnou být na řadě, zatímco je obrazovka otevřená.
- Překlad starých zadání kartiček se spustí jen jednou, dřív se mohl spustit dvakrát. Kolečko „Překládám…“ se ukazuje jen u zástupného textu.
- Gramatický dril odroluje dolů i u chybové odpovědi.
- Pole s API klíčem si pamatuje rozepsaný text i po odscrollování.
- Ukončení hlasového tutora zruší všechny časovače. Dřív mohl jeden zůstat běžet.

### Otevřené body a doporučení
1. **Ruční test na zařízení** (oddíl *Kontrola změn*) projít před sloučením do `main`.
2. **`voice_tutor_agent.dart` má pořád 1232 řádků.** Dalším krokem je vyčlenit do `services/agents/voice_tutor/` spuštění a ukončení lekce (`startSession` má asi 200 řádků, `stopSession` asi 120) a zpracování zvuku z mikrofonu (`_handleIncomingAudioChunk`, `_processAudioChunkForVAD` a časovače, asi 190 řádků). Dělat to až po úspěšném ručním testu. Jde o řízení živého hovoru a reálný zvuk automatické testy nepokryjí.
3. **Další soubory nad 600 řádků.** Rozdělit je, až se na nich bude pracovat:
   - `core/app_theme.dart` (781): oddělit barvy od `ThemeData` a `TextTheme`.
   - `features/conversation/widgets/word_translation_sheet.dart` (750): překlad, uložení do kartiček a vrácení zpět přesunout ze stavu widgetu do controlleru. Metodu `build` (přes 400 řádků) rozdělit na menší widgety.
   - `features/conversation/widgets/interactive_tutor_text.dart` (639): rozpoznávač gest dát do vlastního souboru. Rozdělení textu na slova (včetně `**tučně**` a `*kurzívy*`) vytáhnout do čisté funkce a otestovat.
   - `services/gemini/gemini_live_client.dart` (630): zpracování zpráv ze serveru (`_handleIncomingMessage`, asi 190 řádků) přesunout do samostatného parseru. Klientovi zůstane připojení, reconnect a odesílání.
4. **`features/history/history_screen.dart` se v aplikaci nepoužívá**, a to už před refaktoringem. Odkazují na ni jen testy, historie lekcí je v záložce Pokrok. Je potřeba rozhodnout, jestli ji smazat i s testem, nebo vrátit do navigace.
5. **Migrace databáze (zatím odloženo).** Opravy schématu a deduplikace kartiček v `beforeOpen` (`data/database/app_database.dart`) běží při každém startu aplikace. Doporučený postup: zvýšit `schemaVersion` na 4, opravy přesunout do `onUpgrade` a přidat test migrace na starší databázi. Změna se týká dat uložených v zařízení, proto zatím počkala.
6. **Kartičky smazané chybnou deduplikací se samy nevrátí.** Jejich chyby mají dál příznak `in_flashcard`, takže z nich nové kartičky nevzniknou a detail lekce u nich ukazuje, že už v kartičkách jsou. Příznaky by šlo vynulovat u chyb, ke kterým žádná kartička neexistuje. Tím by se ale vrátily i chyby záměrně vyřazené z generování a chyby, jejichž kartičky byly smazané ručně, proto to zatím neproběhlo.
