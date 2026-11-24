# 🇬🇧 AJ Tudor – Konverzační AI Tutor angličtiny

**AJ Tudor** je pokročilá mobilní aplikace ve **Flutteru** pro výuku a procvičování konverzační angličtiny v reálném čase. Využívá **Google Gemini Multimodal Live API** (WebSocket Audio-to-Audio streamování) a multi-agentní architekturu pro přirozený, plynulý hlasový dialog bez znatelné latence.

---

## 🌟 Klíčové vlastnosti

- 🎙️ **Real-time hlasová konverzace (A2A)**: Obousměrný WebSocket přenos surového PCM audia přímo do modelu Gemini Live (výchozí `gemini-3.8-live`, odezva pod 1 sekundu).
- 🤖 **Multi-agentní systém**:
  - **Voice Tutor Agent**: Řídí živý hlasový dialog, místní detekci řeči (VAD), která serveru ohlašuje začátek a konec řeči studenta, opravný přepis replik studenta a ochranu proti repetici.
  - **Memory Manager Agent**: Po skončení lekce asynchronně analyzuje transkript pomocí *Structured Outputs (JSON)*, sleduje chyby, slovní zásobu a aplikuje Ebbinghausovu křivku zapomínání.
- 📝 **Inteligentní telemetrie chyb & Memory Pruning**: Po skončení hovoru `MemoryManagerAgent` přes *Structured Outputs (JSON)* provede detailní rozbor chyb, extrahuje nová slovíčka, odnaučuje zvládnuté jevy a automaticky vytváří kartičky (Smart Flashcards) k procvičení.
- 🗂️ **Smart Flashcards s opakováním (SRS)**: Kartička se otočí až po pokusu o odpověď (hlasem s hodnocením výslovnosti, napsáním, nebo „Nevím“), takže ji nejde ohodnotit bez zkoušení.
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
│   ├── utils/             # Logger, Result, české tvary podle počtu (czechPlural)
│   ├── widgets/           # Prvky vzhledu: povrch karty (GlassContainer), skupina řádků a nadpisy (GroupedSection), přepínač (PillTabs), malý graf (Sparkline)
│   └── app_theme.dart     # Tmavý vzhled: barvy, písmo (AppTheme.font) a ThemeData
├── data/                  # Datová vrstva (Drift ORM, SQLite)
│   ├── database/          # Schéma Drift (AppDatabase, tabulky)
│   ├── models/            # Datové modely a SRS plánovač opakování kartiček
│   ├── repositories/      # Repozitáře: lekce, profil studenta, scénáře, kartičky, evidence témat
│   └── data_providers.dart  # Providery databáze, repozitářů a datových streamů
├── features/              # Obrazovky dle domény: obrazovka skládá layout, části jsou ve widgets/, akce v *_controller.dart
│   ├── agents/            # Přehled agentů
│   ├── conversation/      # Hlasový tutor, gramatický dril (GrammarDrillController), chat bubliny, překlad slov
│   ├── flashcards/        # Smart Flashcards: FlashcardsController, průběh opakování (ReviewSession), výslovnost, napsaná odpověď (TypedAnswer)
│   ├── history/           # Historie lekcí a detail lekce (SessionDetailController)
│   ├── progress/          # Statistiky, grafy, přehled chyb a slovíček
│   ├── settings/          # Nastavení (API klíč, hlas, modely, záloha) a ProfileSettingsController
│   └── skeleton/          # Navigační shell (spodní lišta s Hovorem uprostřed) a provider aktivní záložky
└── services/              # Aplikační logika – každá služba má svůj provider ve stejném souboru/složce
    ├── agents/            # VoiceTutor, VoiceDirector, MemoryManager, ScenarioPlanner, TopicPreparation
    │   └── voice_tutor/   # Části hlasového tutora: detekce řeči (VAD), časovače, metriky, analýza přepisu
    ├── audio/             # Nahrávání mikrofonu (record) a přehrávání (flutter_pcm_sound)
    ├── flashcards/        # Tvorba kartiček pomocí AI (z chyb, z oprav v chatu, nová slovíčka, překlad zadání)
    ├── gemini/            # Gemini Live (WebSocket), společné REST jádro a služby (batch, TTS, výslovnost, překlad)
    ├── notifications/     # Lokální připomínky
    ├── prompt/            # Všechny prompty: SystemPromptBuilder (agenti), LiveTutorPrompts (pokyny během hovoru), TaskPrompts (krátké úlohy)
    ├── system/            # Wakelock, záloha databáze
    └── topics/            # Evidence témat: katalog oblastí (TopicCatalog), plánovač s odstupy (TopicPlanner), zpětné doplnění ze souhrnů
```

### Pravidla struktury
- Závislosti vedou jedním směrem: `features → services → data → core`. Nižší vrstva nikdy neimportuje vyšší.
- Aplikace má jen tmavý vzhled („Noční studio“). Barvy a písmo berte z `AppTheme` (`AppTheme.font`, `textPrimary`, `surface`…), sdílené prvky z `core/widgets/`. Obsah patří do skupin řádků (`GroupedSection`), ne do samostatných barevných karet. Barva jen pro význam: stav hlasové vlny a lepší/horší u čísel. Ikona ovládacího prvku má vždy popisek nebo `tooltip`.
- Widgety nevolají AI ani nezapisují do databáze přímo. Jde to přes controller ve složce obrazovky, přes službu nebo přes agenta. Data z databáze čtou přes `StreamProvider`y v `data/data_providers.dart`.
- Soubor obrazovky jen skládá layout. Větší části patří do `widgets/`, akce do `*_controller.dart`.
- Provider služby leží ve stejném souboru nebo složce jako služba. Providery databáze, repozitářů a datových streamů jsou v `data/data_providers.dart`.
- Texty promptů jsou jen v `services/prompt/`.
- Volání Gemini REST API jdou přes `GeminiRestCore` (`services/gemini/gemini_rest_core.dart`). Jádro střídá modely, dává přetížené modely na cooldown a třídí chyby. Vlastní `Dio` jinde nevytvářejte. API klíč posílá v hlavičce `x-goog-api-key`, do adresy požadavku nepatří (adresa se dostává do textu výjimek a tím do logu).
- Bezplatná úroveň má u `gemini-3.8-flash` a `gemini-3.6-flash` jen 20 požadavků denně, u flash-lite modelů 500 a u `gemini-3.8-flash-tts` 10. Často volané úlohy (režisér, překlad slov, výslovnost) proto začínají flash-lite modely a 3.8 Flash zůstává pro rozbor po lekci, přípravu témat a scénáře. Opravný přepis běží u každé repliky studenta, proto taky začíná flash-lite a 3.6 Flash je až poslední záloha (dřív začínal 3.6 Flash a jedna lekce spotřebovala celý jeho denní limit). Vyčerpaný denní limit (odpověď 429 s `PerDay`) vyřadí model ve všech službách až do obnovy kvóty (půlnoc pacifického času, u nás 9:00), minutový limit na minutu.
- Soubor v `lib/` by neměl mít víc než zhruba 600 řádků. Výjimkou je generovaný `app_database.g.dart` a `system_prompt_builder.dart`.

### Použité balíčky (Dependencies)
- **State Management**: `flutter_riverpod`
- **Database & Storage**: `drift`, `sqlite3`, `flutter_secure_storage`, `shared_preferences`
- **Audio Pipeline**: `record` (PCM 16-bit 16kHz mono), `flutter_pcm_sound` (PCM 16-bit 24kHz mono)
- **Networking & AI**: `web_socket_channel` (Gemini Live WebSocket), `dio` (REST API pro analýzy)
- **UI & Grafy**: `fl_chart`, `google_fonts` (Hanken Grotesk), `wakelock_plus`

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
Po prvním spuštění přejděte na záložku **Profil** (Nastavení) a vložte svůj **Gemini API klíč**. Následně můžete okamžitě zahájit hlasovou konverzaci.

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
4. **Ruční detekce řeči**: Serverová detekce řeči je vypnutá (`automaticActivityDetection.disabled`). Začátek a konec řeči studenta určuje místní detekce (`SpeechActivityDetector`) a aplikace je serveru ohlašuje zprávami `activityStart` a `activityEnd`. Replika se začne nahrávat po 200 ms souvislého hlasu, krátký ruch (klepnutí, nádech, dozvuk reproduktoru) ji tedy ani nezačne. Serveru se pošle (`activityStart` a dosud nahraný zvuk) až od 0,7 s hlasu. Kratší replika („yes“, ale i zakašlání nebo „hm“) se během ticha po ní ověří opravným přepisem. Tudorovi se pošle, jen když v ní je řeč, jinak se zahodí, takže na ruch nereaguje a živý přepis z něj neudělá „¿Qué?“. Zvuk se posílá jen mezi `activityStart` a `activityEnd`, zhruba půl sekundy úvodu před zjištěnou řečí doplní `PreRollBuffer`. Konec řeči nastane po tichu „trpělivost učitele + 0,5 s“ a model pak hned odpoví. Pauza rozpracovanou řeč neukončí, po obnovení může student větu dokončit. Server oba signály potvrzuje zprávou `voiceActivity`. Začátek další řeči i s jejím zvukem odejde až po potvrzení konce té předchozí, nejpozději po 3 s, protože dřív poslaný `activityStart` server zahodí a na řeč už neodpoví. Když server konec řeči do 3 s nepotvrdí, tah se ztratil a spojení se obnoví hned. Jinak se obnoví, když model do 11 s od první nezodpovězené repliky neodpoví, a tutor pak na poslední repliku hned odpoví. Další replika studenta („Haló?“) lhůtu nevynuluje, jen modelu dá na odpověď aspoň 5 s. Uprostřed řeči studenta se spojení neobnoví.
5. **Opravný přepis**: Živý přepis Gemini Live občas zapíše řeč studenta jiným jazykem („¿Qué?“). Zvuk každé repliky (`StudentUtterance`) se proto po jejím konci přepíše znovu přes `SpeechTranscriptionService` s pokynem, že student mluví česky nebo anglicky. Výsledek nahradí text v bublině a do databáze se uloží až ten. Na jeden model čeká nejvýš 9 s, aby se při zaseknutí stihl zkusit další, celý přepis má 20 s. Když přepis selže, uloží se živý přepis. Když opravný přepis v nahrávce řeč neslyší, krátký živý přepis (nejvýš dvě slova, typicky „¿Qué?“ na ruch) se zahodí i z bubliny. Konec lekce na rozpracované přepisy počká nejvýš 8 s.
6. **Skryté pokyny**: Rady režiséra (`VoiceDirectorAgent`) a další pokyny během hovoru jdou jako `clientContent`. Taková zpráva podle dokumentace Live API přeruší odpověď, kterou model právě generuje, proto pokyny čekají ve frontě a odešlou se až po `turnComplete` tutora. Hned se posílá jen „Změnit téma“, kde je přerušení záměr.
7. **Souvislý hovor (výchozí stav zapnuto od 17. 11.)**: přepínač v Nastavení, platí od příští lekce. Logiku drží `LiveSessionContinuity` (`services/gemini/live_session_continuity.dart`).
   - Spojení pošle v `setup` pole `sessionResumption` a `contextWindowCompression`. Server pak posílá `sessionResumptionUpdate` s tokenem. Bere se jen token označený `resumable`, jinak platí předchozí.
   - Tokenem se navazuje po výpadku sítě, po zavření spojení pro nečinnost během pauzy, po `goAway`, po návratu z pozadí a po zásahu watchdogu. Nové spojení pak shrnutí nedostane. Zůstala-li poslední replika studenta bez odpovědi, tutor dostane pokyn odpovědět na ni (`LiveTutorPrompts.answerAfterResume`).
   - Bez tokenu, se shrnutím jako dosud, začíná spojení obnovené proto, že model neodpovídá, že se zacyklil na řídicích tokenech, nebo že kontext přesáhl 25 tisíc tokenů. Na zaseknutý nebo příliš velký hovor nemá smysl navazovat.
   - Když server navázání odmítne, protože předchozí spojení ještě drží (kód 1008, „already connected to an existing client“, typicky po výpadku sítě), token se zahodí a nové spojení se shrnutím se naváže hned. Na uvolnění starého spojení se nečeká, v lekci 33 trvalo přes 18 s.
   - Když server spojení zavře s kódem dřív, než potvrdí nastavení, ubírá se postupně: nejdřív token, pak komprese, nakonec i žádost o token. Lekce pak běží jako bez souvislého hovoru a důvod je v logu („Souvislý hovor: server odmítl…“). Zavření bez kódu je síť a token zůstává.

---

## 🧪 Kontrola změn

Před každým commitem spusťte:

```bash
dart analyze lib test   # statická analýza
flutter test            # všechny testy, podrobnosti v test/README.md
```

Na cestě s diakritikou (např. `D:\Programování\…`) `flutter analyze` padá na chybě `FormatException`. `dart analyze` provede stejnou kontrolu a funguje. Ze stejného důvodu vypíše `flutter run` na začátku červené řádky od `aapt` (`Illegal byte sequence`, `Failed to extract manifest from APK`). Flutter si pak manifest vezme ze zdrojáků a aplikace se nainstaluje normálně.

Pravidla struktury (směr závislostí, délka souborů, jediné místo s `Dio`, API klíč mimo adresu požadavku) hlídá `test/architecture_test.dart`, takže běží s ostatními testy. Soubory, které limit délky překračují s vědomím, má test vyjmenované v `knownOversized`.

Stejné kontroly pouští při každém pushi GitHub Actions (`.github/workflows/ci.yml`). Testy nevolají Gemini, takže kvótu API nespotřebují.

Ručně jde směr závislostí ověřit v Git Bash. Žádný z příkazů nesmí nic vypsat:

```bash
grep -rnE "import '.*(services|data|features)/" lib/core   # core neimportuje nic z aplikace
grep -rnE "import '.*(services|features)/" lib/data        # data neimportuje services ani features
grep -rn "features/" lib/services                          # services neimportuje features
```

Největší soubory (hranice je zhruba 600 řádků):

```bash
find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | sort -rn | head
```

### Test promptu tutora

Změny systémového promptu hlasového tutora se ověřují na skutečných replikách z lekcí přes `tool/prompt_eval/` (návod v `tool/prompt_eval/README.md`). Před změnou se uloží výchozí běh a po změně se porovná.

### Log z telefonu
Výpis z konzole je na sdílení obvykle moc dlouhý. Ladicí verze proto ukládá log i do souboru v úložišti aplikace. Stáhnete ho v Git Bash:

```bash
adb exec-out run-as com.tudor.aj_tudor cat app_flutter/logs/latest.log > latest.log
```

Každé spuštění aplikace začne nový `latest.log`, předchozí běh zůstane v `previous.log`.

Každá hlasová lekce má navíc vlastní log `logs/sessions/session_<id>.log`, který restarty aplikace přežije (drží se posledních 30 lekcí). Problém, který se v lekci projevil, jde popsat v detailu lekce tlačítkem „Nahlásit problém“, nebo dlouhým stiskem repliky, u které se projevil. Popis se uloží do tabulky `session_issues`. Postup rozboru je v `CLAUDE.md`.

API klíč se do logu nedostane: logger v každém řádku nahradí hodnotu parametru `key=` i samotný klíč (`AIza…`) hvězdičkami.

### Ruční test na zařízení
Automatické testy nepokryjí mikrofon, přehrávání zvuku ani skutečné volání Gemini. Po větších změnách projděte na telefonu:

- [ ] Hlasová lekce: start, pauza a obnovení (i přes překlad slova), stop
- [ ] Hlasová lekce: tutor odpoví hned po domluvení, pauza uprostřed věty a dokončení věty po obnovení, věta v češtině má v historii český přepis
- [ ] Nahlášení problému v detailu lekce (tlačítkem i dlouhým stiskem repliky)
- [ ] Hlasová lekce: věta se dvěma chybami (tutor je opraví postupně, vždy jednu), tutor se neutíná uprostřed věty
- [ ] Překlad slova (klepnutí) a fráze (podržení a tažení), uložení do kartiček tlačítkem
- [ ] Scroll přes text tutora v drilu i v hlasové lekci, česká slova nejdou označit
- [ ] Tlačítko „Do kartiček“ u opravy v chatové bublině
- [ ] Opakování kartiček: odpověď hlasem, napsáním i „Nevím“ (pak jde jen „Znovu“), přehrání nahlas
- [ ] Pokrok: „Co se zlepšuje“ (ukazatele s grafem posledních lekcí, u všech je víc líp) a „Na čem pracovat“ (chyby podle druhu, předtím → teď) se ukážou po první lekci s novým rozborem, detail lekce ukáže „Tvoje řeč: N % slov“
- [ ] Vzhled: spodní lišta s Hovorem uprostřed se během hovoru schová, výběr druhu hovoru rozbalí vybraný řádek, během hovoru je nahoře velká vlna a klepnutím na ni se mluvící Tudor ztiší
- [ ] Lekce: řádek „Lekce s kartičkami“ ukáže výrazy, tutor je projde jeden po druhém (situace, česká nápověda, výraz a zopakování), na obrazovce „Lekce: N/10 výrazů“, po posledním výrazu nebo po 15 minutách lekci uzavře a nabídne pokec
- [ ] Kartičky v hovoru: výraz z dnešní kartičky řečený sám od sebe ukáže „Kartička splněna v hovoru“, po konci hovoru přijde souhrn a kartička zmizí z dnešního opakování; zopakování po tutorovi kartičku nesplní
- [ ] Chat nad lekcí (detail lekce v záložce Pokrok) a gramatický dril
- [ ] Nastavení: přepínače, úroveň angličtiny, přidání a smazání faktu „O mně“
- [ ] Záloha a import: po obnově jsou data vidět hned bez restartu aplikace, poškozený nebo cizí soubor se odmítne a data zůstanou
- [ ] Hlasová lekce na pomalé síti (mobilní data): tutor pozdraví, i když se spojení připraví později než za vteřinu
- [ ] Hovor bez oprávnění k mikrofonu: ukáže se chyba mikrofonu a displej smí zhasnout
- [ ] Rozbor lekce bez sítě (letadlový režim hned po hovoru), pak aplikaci ukončit a spustit znovu se sítí: rozbor se dokončí sám
- [ ] Aplikaci ukončit hned po konci hovoru (rozbor ještě běží) a spustit znovu: v logu je „Opakuji rozbor lekce“ a lekce rozbor dostane
- [ ] Souhrn lekce v logu: „user:“ odpovídá počtu replik studenta a `ai_response_latency` vychází na stovky až tisíce ms
- [ ] Souvislý hovor (přepínač v Nastavení): lekce začne normálně a v logu je „Souvislý hovor: žádám server o token“ a `SessionResumptionUpdate … token přišel`. Po dvouminutové pauze: v logu „navazuji tokenem“ a „spojení navázalo na stejný hovor“, tutor pokračuje bez nového pozdravu. Po vypnutí a zapnutí Wi-Fi uprostřed hovoru: server token odmítne (1008), hned potom „Zkusím to bez něj“ a do vteřiny „Spojení obnoveno“, tutor naváže podle shrnutí
- [ ] Odchod z aplikace během hovoru (tlačítko Domů nebo zhasnutí displeje): v logu „Aplikace odešla na pozadí, hovor pozastavuji“, po návratu je hovor pozastavený a pokračuje klepnutím na Pokračovat. Stažení lišty oznámení hovor nepozastaví
- [ ] Ukončení lekce: po klepnutí na Ukončit je vidět „Ukončuji lekci…“, další klepnutí nic nespustí a po konci lekce nesvítí ukazatel mikrofonu
- [ ] Souvislý hovor v lekci delší než 15 minut: spotřeba tokenů (`UsageMetadata`) se drží pod 20 tisíci a spojení se kvůli limitu neobnovuje
- [ ] Reset paměti, jen pokud vám nevadí přijít o to, co si Tudor pamatuje

---

## 🛠️ Doladění evidence témat, promptů a modelů (24. 11. 2026)

Úpravy navazují na kontrolu Free Tier modelů, logů z telefonu (`latest.log`, `session_36.log` až `session_38.log`) a databáze témat (`topic_history`):

- **Modely pro Free Tier (ověřeno 24. 11. 2026):** `gemini-4-neon`, `gemini-4-carbon`, `gemini-4-argon`, `gemini-omni-1.2-flash` a `gemini-3.1-pro-preview` mají na bezplatné úrovni `limit: 0` (429); v UI výběru modelu v Nastavení jsou nově označené jako *Placený tarif*. `gemini-4-hydrogen` a Gemma 4 (`gemma-4-31b-it`, `gemma-4-26b-a4b-it`) na Free Tier jsou, ale často vrací 503. `gemini-2.5-flash-lite` už vrací 404. Spolehlivě a rychle na Free Tier běží `gemini-3.5-flash-lite` (500 RPD), `gemini-decision-1` (10 000 RPD) a `gemini-3.8-live`.
- **Odolná evidence témat (`topic_history`):**
  - Zpětné zařazení starších lekcí (`TopicHistoryBackfill`) nově používá `geminiTopicBackfillClientProvider` (jen `3.5-flash-lite` a `3.1-flash-lite`, od 24. 11. večer bez záložních 3.6 a 3.8 Flash, aby jejich limit 20 RPD zůstal rozboru lekcí), takže na Free Tier nepadá na 503/limit 20 RPD, a příznak dokončení uloží jen tehdy, když opravdu zapíše témata (nebo když v DB žádné starší lekce nejsou).
  - `loadTopicPlan` při prázdné `topic_history` kontroluje, zda už proběhl backfill u existujících lekcí; dokud nedoběhne, vrátí prázdný plán, aby nedávno probrané oblasti neoznačil jako „nové“.
  - `TopicPreparationAgent` vynechává nedávno navržené `areaId` při opakovaném klepnutí na *Jiné téma*; `VoiceTutorAgent` po hovoru s alespoň jednou replikou studenta připravené téma spotřebuje (`consumeTopic()`) a při přepnutí tématu během hovoru posouvá nabídku na další oblasti; `ScenarioPlannerAgent` před plánováním spustí backfill.
  - Reset paměti v Nastavení nově smaže i `topic_history` a příznak backfillu; obnova ze zálohy příznak backfillu vyčistí; `HistoryTopicTab` zobrazuje nad názvem tématu i název jeho oblasti; oblast `uceni` nekolizuje se stop-biasem proti „škole a dětem“.
- **Odstranění kolizí v promptech a opakování režiséra:**
  - `VoiceDirectorAgent` si pamatuje své poslední 4 rady v hovoru (`_recentWhispers`), dostává `scenarioContext` při role-play (aby neutíkal do nepodstatných drobností a nepřepínal mimo scénář) a loguje správně `flash-lite`.
  - V `SystemPromptBuilder` sjednoceny pokyny k faktům z profilu a `memoryBriefing` (odstraněno protichůdné „na fakta přirozeně navaž“, plánovač scénářů s `TopicPlan` nedostává `memoryBriefing`), sjednoceno pravidlo jedné otázky u jednoslovných odpovědí, nahrazeny IT příklady u režiséra a tutor dostává jen instrukci pro svou aktuální CEFR úroveň.

## 🛠️ Úpravy po lekcích 36–38 (21. 11. 2026)

Úpravy vzešly ze sledování lekcí 36 až 38 naživo a z rozboru všech lekcí v databázi. Testů je 617.

- **Build:** `flutter_local_notifications` 23 vyžaduje compileSdk 37 (`androidx.core` 1.19). Aplikace i pluginy (vynucení v `android/build.gradle.kts`) kompilují proti 37, AGP zůstal na 9.1.0.
- **Chat po hovoru:** po ukončení hovoru zůstával chat bez ovládání a výběr tématu vrátil jen restart aplikace. `stopSession` teď zprávy maže, přepis zůstává v historii.
- **Skákání mezi tématy (lekce 36):** režisér radil změnu tématu, i když ji sám hlásil jako zbytečnou, rada z dřívějška přebila nové téma studenta a zacyklení „repeat your answer“ při smrkání spustilo vynucenou změnu tématu i detekci frustrace. Režisér teď s `needsPivot=false` rozvíjí aktuální téma, rada má podmínku „jen když ještě sedí“, opakovanou žádost o zopakování řeší pokyn `breakRepairLoop` (téma se nemění) a po zásahu se nuluje počítadlo krátkých odpovědí. Pokyn při frustraci zjednoduší otázku ke stejnému tématu.
- **Ověření krátké repliky:** varování „se do N ms hlasu nevejde“ se zapisovalo i u ověření zrušeného pokračující řečí. Kontrola je teď až v `_finishShortUtterance`. Přepisovač si z útržků kolem 0,2–0,5 s vymýšlí celé česko-anglické věty, pojistka je zahodí (viz *Otevřené body*).
- **Hovory se točily kolem práce a IT:** v 22 z 34 lekcí otevřel práci nebo IT tutor, student jen ve 3. Rozbor po lekci zapisoval do paměti „zaměř se výhradně na IT a SaaS projekt“, tutor měl navázat na doporučené téma z paměti a plánovač scénářů na ně navazovat musel (tři scénáře o IT). Test na Gemini se současným profilem: starý prompt stočil k IT 5 ze 6 tahů tutora, nový žádný.
- **Evidence témat (`topic_history`, schéma 5):** rozbor po lekci zařadí probraná témata do jedné z 22 oblastí katalogu (`TopicCatalog`). Starší lekce se při prvním spuštění doplní ze souhrnů jedním dotazem (`TopicHistoryBackfill`). `TopicPlanner` z evidence spočítá, které oblasti odpočívají (2, 4, 7 dní podle počtu lekcí, nejvýš podle nastavení *Návrat k probranému tématu*, výchozí týden), a nabídne tři oblasti, aspoň jednu novou. Nabídku dostává příprava tématu (místo přepisů a souhrnů minulých lekcí), plánovač scénářů (každý scénář z jiné oblasti), režisér při změně tématu, úvod volného pokecu, tlačítko Jiné téma i změna tématu při zacyklení. Kartičky se k tématu vybírají, téma se kvůli nim nemění. Briefing pro příště téma nedoporučuje.

## 🛠️ Úpravy po lekci 33 (17. 11. 2026)

Úpravy vzešly z logu lekce 33 (17. 11., 20 minut se souvislým hovorem a jedním vypnutím Wi-Fi). Komprese kontextu v ní zasáhla třikrát a hovor běžel do výpadku Wi-Fi na jednom spojení. Úpravy na telefonu ještě neběžely v lekci. Testů je 582: časomíra a pauza na pozadí po jednom přidaly, dva testy opakování navázání nahradil jeden.

- **Časomíra hovoru:** hlavička hovoru ukazuje vpravo od názvu, jak dlouho hovor trvá (`MM:SS`). Během pauzy se zastaví, délka lekce v historii pauzy zahrnuje.
- **Dávkový překlad kartiček:** dvakrát selhal, model místo JSONu odpověděl jako tutor („Well, I think there is a little misunderstanding here…“). `GeminiBatchClient` bez zadaného systémového promptu posílal prompt hlasového tutora. Teď `system_instruction` posílá jen se zadaným promptem.
- **Navázání po výpadku sítě:** server mrtvé spojení držel ještě 18 s po výpadku Wi-Fi. Všechna čtyři opakování navázání tokenem po 2 s skončila `1008 … already connected to an existing client` a hovor dostal shrnutí až asi 13 s poté, co se síť vrátila. Klient teď token zahodí po prvním takovém odmítnutí a nové spojení naváže za 0,3 s místo po 2 s prodlevy mezi pokusy. Okamžité navázání platí pro každé odmítnuté nastavení, ubírat se dá nejvýš třikrát.
- **Denní připomínky:** plánují se přes `inexactAllowWhileIdle`. Přesné budíky na Androidu 14+ vyžadují zvláštní oprávnění (`exact_alarms_not_permitted`).
- **Souvislý hovor je výchozí:** přepínač v Nastavení je bez „(zkušební)“ a bez uložené volby je zapnutý. Lekce 28, 29 a 33 ověřily navázání po pauze, kompresi kontextu i návrat ke shrnutí po výpadku sítě.
- **Odchod na pozadí hovor pozastaví** (`AppLifecycleState.hidden` a `paused`). Aplikace nemá službu na popředí, takže jí Android na pozadí ztlumí mikrofon. Tutor by slyšel ticho a server by spojení po chvíli zavřel. Po návratu hovor zůstane pozastavený a pokračuje se klepnutím na Pokračovat. Stav `inactive` (lišta oznámení, systémový dialog) hovor nepozastaví.
- **Smazaná `history_screen.dart`:** obrazovka se v aplikaci nepoužívala, historie lekcí je v Pokroku. Její testy teď ověřují záložku `LessonHistoryTab`.
- **Lekce 30 a 32 (pozorování):** server třikrát nepotvrdil konec řeči studenta a agent spojení obnovil. Pokaždé šlo o spojení bez tokenu, dvakrát hned po navázání. V tu dobu vracely 503 i textové modely, nejspíš tedy šlo o zaseknutí serveru (viz *Otevřené body*, bod 7).

## 🛠️ Úpravy z otevřených bodů (17. 11. 2026)

Úpravy navazují na body 16–20 v *Otevřených bodech* a na poznatky z lekcí 28 a 29. Na telefonu ještě neběžely. Počet testů vzrostl z 575 na 581.

- **Ověření modelů Gemini 4 (`GEMINI_API_KEY`):** `gemini-4-hydrogen` na bezplatné úrovni je (nevrátil 429 `limit: 0`), ale dva dotazy se strukturovaným JSON schématem vypršely po 25–30 s bez odpovědi a prostý dotaz vrátil `HTTP 503` (stejně přetížený jako `gemini-3.8-flash`). Zařazení před `3.8-flash` by čekání jen zdvojnásobilo, takže v pořadí zůstává beze změny. `gemini-4-argon` vrátil `HTTP 429` s `limit: 0` pro Free Tier. `gemini-3.8-flash` a `gemini-3.6-flash` vrátily `HTTP 503`, `gemini-3.5-flash-lite` odpověděl `HTTP 200`.
- **Detekce opakování tutora (bod 20):** `repeatedTurnSimilarity` nyní vyžaduje podobnost aspoň se dvěma předchozími promluvami v historii (`minMatches = 2`). Jedno zopakování otázky (když student nerozuměl, po výpadku sítě nebo při návratu po opravě) téma nemění; tichá změna tématu se pošle až potřetí.
- **Delší cooldown při opakovaném přetížení a preference funkčního modelu (bod 17):** `ModelCooldownTracker` při po sobě jdoucích selháních (mimo 429) prodlužuje cooldown (×1 → ×5 → ×20, u 3 min tedy 3 → 15 → 60 minut), dokud model neuspěje. `GeminiBatchClient` si pamatuje poslední funkční model a u krátkých úloh (`shortTaskTimeout`) s ním začíná; rozbor lekce (`longTaskTimeout`) dál začíná nejsilnějším dostupným modelem mimo cooldown.
- **Detekce krátkých odpovědí / frustrace (bod 18):** `_flushUserTranscript` kontroluje délku skutečné řeči (`utterance.voicedMs >= 3000`) místo celé nahrávky (`audioMs`), která zahrnovala i 2 s ticha na konci a úvod z `PreRollBuffer`.
- **Jednoslovné kartičky v pokecu (bod 19):** `ConversationCards.completeBy` s `includeSingleWords: false` splní doslova jen víceslovné výrazy; jednoslovné cíle (`matchingSingleWords`) ověřuje `LessonCardJudge` podle významu z české strany a slovního druhu.
- **Export zálohy a úklid mrtvého kódu (bod 16):** `BackupService.exportBackup()` kopíruje databázi do dočasného souboru zálohovacím API SQLite (`_copyDatabase`), takže funguje bezpečně i při otevřeném spojení a se soubory WAL. Z `GeminiLiveClient` a `VoiceTutorAgent` byla odstraněna nepoužívaná obsluha `toolCall`.

## 🛠️ Úpravy po lekcích 28 a 29 (14. 11. 2026)

Úpravy vzešly z logů lekce 28 (12. 11., deset minut pokecu se zapnutým souvislým hovorem, jedním vypnutím Wi-Fi a několika pauzami) a lekce 29 (12. 11., skoro 18 minut se souvislým hovorem bez výpadku). Na telefonu ještě neběžely. Počet testů vzrostl z 571 na 575.

- **Komprese kontextu funguje, jen později, než bylo nastaveno:** v lekci 29 spotřeba tokenů rostla až na 24 404 a v dalším tahu spadla na 14 192. Tutor po zkrácení navázal na to, co student řekl o dva tahy dřív. Práh byl 20 000, server ho ale počítá jinak než `usageMetadata.totalTokenCount`. Zkrácení tak přišlo jen 600 tokenů pod hranicí 25 tisíc, při které agent spojení obnovuje se shrnutím, a o trochu delší tah by kompresi zmařil. Práh je teď 16 000, zkracování má přijít kolem 20 tisíc.
- **Lekce 29 běžela 17 minut 37 vteřin na jednom spojení** (39 odpovědí tutora, sedm pauz do 35 s, žádná obnova spojení, žádný `goAway`). Prostřední reakční doba tutora byla 1 041 ms, nejdelší 2 252 ms.
- **Rozbory lekcí 27, 28 a 29 jsou hotové.** Lekci 27 dokončilo automatické opakování, lekci 29 rozebral až `gemini-3.1-flash-lite` (3.8 Flash i 3.5 Flash-Lite vrátily 503).
- **Nové modely Gemini 4** (`gemini-4-carbon` z 10. 11. a `gemini-4-hydrogen` z 12. 11.) jsou v seznamu modelů pro textový chat. Modely, které aplikace používá jinde, se nezměnily a žádný nemá ohlášené vypnutí kromě `gemini-3.1-flash-lite` (7. 5. 2027).

- **Souvislý hovor na telefonu, co se potvrdilo:** server pole `sessionResumption` i `contextWindowCompression` přijal a hned poslal token. Po dvouminutové pauze zavřel spojení pro nečinnost (1008), nové spojení se přihlásilo tokenem a tutor pokračoval v hovoru bez shrnutí. Spotřeba tokenů navázala (11 992 před pauzou, 12 945 po první odpovědi po ní), kontext tedy na serveru zůstal.
- **Navázání po výpadku sítě:** deset vteřin po vypnutí Wi-Fi server navázání odmítl s kódem 1008 a důvodem „BidiGenerateContent session is already connected to an existing client“. O konci starého spojení ještě nevěděl. Klient token zahodil, hovor dostal shrnutí a tutor po něm navázal na téma. Teď klient při tomhle důvodu token nechá a navázání zkusí znovu, nejvýš čtyřikrát po 2 s (`LiveSessionContinuity.retryWhileStillConnected`). Když server spojení uvolní, log zapíše, za jak dlouho. Jinak přijde shrnutí jako dosud, jen asi o 10 s později. Opakování v lekci 33 ani jednou nevyšlo a od 17. 11. ho klient nezkouší (*Úpravy po lekci 33*).
- **Ukončování lekce:** uložení posledních replik čeká až 8 s na opravný přepis a hovor během toho vypadal jako běžící. Student klepl na Pauzu a Pokračovat, mikrofon se zapnul znovu, spojení se navázalo znovu a obojí zůstalo po konci lekce viset. Hned po klepnutí na Ukončit je teď na displeji „Ukončuji lekci…“ (`TutorState.ending`) a tlačítka jsou neaktivní. Pauza, pokračování, psaný text, změna tématu ani návrat z pozadí během ukončování nic nespustí.
- **Rozbor při přetížení všech modelů:** rozbor lekce 28 skončil chybou, všech pět modelů vrátilo 503. Takový rozbor se teď zopakuje po návratu do aplikace nebo po jejím spuštění, stejně jako rozbor bez sítě (`GeminiOverloadedException`).
- **Ověřeno na telefonu z úprav 11.–12. 11.:** souhrn lekce 28 hlásí „user: 15, tutor: 16“, průměrnou délku odpovědi 8,8 slova a prostřední reakční dobu tutora 1 061 ms (nejdelší 1 516 ms). Po spuštění aplikace se sám zopakoval rozbor lekce 27 („Opakuji rozbor lekce 27“).

## 🛠️ Úpravy po lekci 27 (12. 11. 2026)

Úpravy vzešly z logu lekce 27 (11. 11., čtyři minuty pokecu, první lekce po revizi kódu) a z porovnání s logy lekcí 8–26. Souvislý hovor a kontroly v CI na telefonu ani na GitHubu ještě neběžely. Počet testů vzrostl z 542 na 571.

- **Reakční doba tutora:** metrika `ai_response_latency` hlásila 0–2 ms, protože se konec řeči studenta zapsal až s první odpovědí tutora. Podle časů v logu tutor odpovídal za 0,8–2,7 s. Čas se teď zapisuje ve chvíli, kdy aplikace ohlásí konec řeči, a souhrn lekce přidá prostřední a nejdelší reakční dobu.
- **Repliky studenta v souhrnu lekce:** souhrn lekcí 17–27 hlásil „user: 0“ a průměrnou délku odpovědi neznal. Počítal se jen živý přepis nahrávek kratších než 3 s, jenže nahrávka obsahuje i 2 s ticha na konci, takže podmínku splnily jen jednoslovné odpovědi. Teď se počítá každá replika uložená do přepisu.
- **Rozbor přerušený ukončením aplikace:** lekce 27 zůstala bez rozboru. 3.8 Flash i 3.6 Flash vrátily 503 a aplikace skončila osm vteřin po hovoru, dřív než odpověděl flash-lite. Oprava z 11. 11. opakovala jen rozbory, kterým chyběla síť. Seznam (`unfinished_analyses`) teď obsahuje i rozbor, který právě běží, takže se po dalším spuštění zopakuje. Rozbor, který selhal z jiného důvodu, se sám neopakuje. Lekci 27 je potřeba rozebrat ručně tlačítkem „Analyzovat“, vznikla ještě se starým seznamem.
- **Souvislý hovor (zkušební, vypnuto):** nový přepínač v Nastavení. Zapnutý hovor požádá server o token pro navázání na stejný hovor (`sessionResumption`) a o průběžné zkracování kontextu (`contextWindowCompression`, od 20 tisíc tokenů na 13 tisíc). Po výpadku se nové spojení přihlásí tokenem a shrnutí od režiséra se neposílá. Obě pole patří přímo do zprávy `setup`. Dřívější pokus měl kompresi v `generationConfig`, což může být důvod, proč ji server odmítal. Podrobnosti jsou v oddílu *Jak funguje Gemini Live Audio Pipeline*, bod 7, a v *Otevřených bodech*, bod 12.
- **Co server posílá sám:** `sessionResumptionUpdate` chodí jednou na začátku každého spojení, i když o něj aplikace nežádá. Log teď zapíše, jestli zpráva nese token a jestli na hovor jde navázat (samotný token ne).
- **Pravidla struktury jako test:** `test/architecture_test.dart` hlídá směr závislostí, délku souborů, jediné místo s `Dio` a klíč mimo adresu požadavku. `.github/workflows/ci.yml` pouští analýzu a všechny testy při každém pushi.
- **Klient pro Live jde testovat bez sítě:** `GeminiLiveClient` dostává funkci, která otevírá WebSocket, a testy mu podstrčí vlastní kanál.

## 🛠️ Úpravy po revizi kódu (11. 11. 2026)

Úpravy vzešly z pročtení kódu, ne z lekce. Na telefonu ještě ověřené nejsou, body k ověření jsou v oddílu *Ruční test na zařízení*. Počet testů vzrostl z 520 na 542.

- **Padající test:** test `detects a copied opening…` čekal shodu prvních 20 znaků, ale `repeatedTurnSimilarity` jich od opravy citované věty porovnává 40. Test odpovídá kódu a testy ze zatoulaného `test/tutor_text_analysis_test.dart` jsou sloučené do `test/services/agents/voice_tutor/tutor_text_analysis_test.dart`.
- **Úvodní replika na pomalé síti:** tutor zkusil pozdravit jen jednou, vteřinu po zapnutí mikrofonu. Když spojení v tu chvíli ještě nebylo připravené, úvod se neposlal a tutor mlčel, dokud nepromluvil student. `GeminiLiveClient` teď ohlásí potvrzené nastavení (`onSetupComplete`) a čekající úvod se pošle hned potom. Časovač úvodu z ukončené lekce už nepošle úvod lekce následující.
- **Nepovedený start hovoru:** displej se rozsvítil ještě před kontrolami a větve s chybou ho nezhasly. Po chybě mikrofonu navíc zůstala lekce v databázi otevřená do příštího startu. Bez API klíče se teď displej nerozsvítí vůbec a start, který selže po založení lekce, hovor ukončí jako každý jiný (`_failStart`). Když lekci nejde založit, ukáže se skutečný důvod místo „Neočekávaná chyba při startu: Failure(…)“.
- **API klíč v logu:** klíč byl v adrese požadavku a Dart adresu vypisuje do textu výjimek (`WebSocketException: Connection to '…?key=…' was not upgraded`, `HttpException: …, uri = …`). Takové výjimky se logují na zhruba dvaceti místech a log se stahuje z telefonu k rozboru. REST volání teď posílají klíč v hlavičce `x-goog-api-key`. Adresa spojení s Gemini Live klíč obsahuje dál, proto logger každý řádek před výpisem projde a klíč nahradí hvězdičkami (`L.redact`). Starší logy v telefonu a dříve stažené soubory klíč obsahovat můžou.
- **Rozbor lekce v jedné transakci:** opakovaný rozbor nejdřív smazal ten předchozí a nový pak zapisoval po částech. Když zápis spadl (třeba na nečekaném tvaru odpovědi modelu), zůstala lekce bez chyb i kartiček. Smazání i zápis teď běží v jedné transakci (`_saveAnalysis`) a při chybě zůstane předchozí rozbor celý.
- **Rozbor čekající na síť přežije ukončení aplikace:** seznam lekcí, kterým při rozboru chyběla síť, byl jen v paměti. Teď je i v nastavení aplikace (`analyses_awaiting_network`) a rozbor se zopakuje také po spuštění aplikace, jakmile se načte API klíč.
- **Obnova ze zálohy:** import smazal soubor databáze a zálohu zkopíroval na jeho místo. Kontroloval jen 16 bajtů hlavičky, takže poškozený soubor nebo přerušené kopírování znamenaly ztrátu dat. Obrazovky si navíc databázi po zavření hned otevřely znovu a soubor se pak vyměnil pod otevřeným spojením, které dál četlo i zapisovalo do smazaného souboru. Záloha se teď nejdřív ověří (`PRAGMA integrity_check` a tabulky `sessions` a `transcripts`), původní data se uloží do `db.sqlite.bak` a obsah zálohy se do databáze zapíše zálohovacím API SQLite v jedné transakci. Soubor databáze se nemaže ani nepřejmenovává. Export zálohy se nezměnil.

## 🛠️ Úpravy po ručním testu (9. 11. 2026)

Úpravy vzešly z lekce 26 (pokec s častými pauzami) a z jejího rozboru.

- **Kontext po pauze:** během dvouminutové pauzy server zavřel spojení pro nečinnost (1008) a klient ho navázal znovu bez kontextu hovoru. Teď nové spojení kontext dostane a pauza zůstane.
- **Podezřele krátký přepis až od 7 s:** zopakované „their parents“ mívá i s tichem na konci 4 s, takže se zbytečně ptal další model.
- **Hlas v pozadí:** mikrofon zachytil 240 ms hlasu ženy, která vedle telefonovala. Ověření krátké repliky z toho podle otázky tutora vymyslelo větu „Eh, so, they were changing at the same time?“ a Tudor na ni odpověděl. Krátká replika se teď ověřuje bez repliky tutora a přepis delší, než se do zachyceného hlasu vejde (tři slova a další na každých 150 ms), je ruch.
- **Okno s překladem roluje:** dlouhá věta s překladem a slovíčky k výběru se na displej nevešla.
- **Rozbor lekce bez sítě:** displej zhasl hned po hovoru a systém aplikaci na pozadí odpojil od sítě. Během rozboru teď displej nezhasne, rozbor, kterému chyběla síť, se zopakuje po návratu do aplikace a modely bez odpovědi kvůli výpadku nedostanou cooldown.
- **Jeden rozbor lekce najednou:** ruční „Analyzovat“ se sešlo s automatickým opakováním a dva rozbory uložily 12 chyb a 10 kartiček. Druhý rozbor teď počká na výsledek prvního a rozbor, který selže, už nehlásí „Analýza dokončena!“.
- **Znovu analyzovat:** rozebranou lekci jde rozebrat znovu. Nový rozbor nahradí chyby a neprocvičené kartičky předchozího, procvičené kartičky zůstanou.
- **Krátké úlohy opravdu čekají nejvýš 20 s:** úprava z 8. 11. se neuplatnila, protože každý dotaz si nastavil 45 s.

## 🛠️ Úpravy po ručním testu (8. 11. 2026)

Úpravy vzešly z lekcí 23 (Lekce s kartičkami) a 25 (pokec).

- **Lekce podle druhu kartičky:** slovíčko se tutor ptá česky jako kartička, gramatiku uzná vlastními slovy a splnění posoudí rozhodčí lekce (viz [plán výuky](docs/plan-vyuky.md), fáze 2).
- **Podezřele krátký opravný přepis:** flash-lite přepsal 13 s řeči jako „Hm,“. Přepis nejvýš dvou slov z nahrávky delší než 4 s teď zkusí další model a platí, jen když ho nikdo nepřekoná. Značka „(ticho)“ před řečí se zahodí.
- **Úroveň jen z delších lekcí:** odhad úrovně se ukládá a počítá jen z lekce, kde student řekl aspoň 150 slov.
- **Skoro stejné kartičky:** nová kartička nevznikne, když existuje kartička lišící se jen tvarem slova (winterize a winterized, mow the lawn a mowing the lawn, `cardTextKey`).
- **Kratší čekání u krátkých úloh:** příprava tématu čekala na zaseknutý 3.8 Flash 45 s. Krátké úlohy (téma, dril, chat, scénáře, kartičky) teď čekají na jeden model nejvýš 20 s, rozbor lekce dál 45 s.
- **Profil dovedností v Pokroku:** jemnější úroveň se zdůvodněním, chyby na 100 slov, slova na repliku a podíl řeči.
- **Pauza a hned obnovení:** stav se přepnul až po vypnutí mikrofonu, takže druhé rychlé klepnutí pauzu zopakovalo místo obnovení. Teď se stav přepne hned a mikrofon se zapíná a vypíná postupně v pořadí klepnutí.
- **Mikrofon u kartiček:** dvojí rychlé klepnutí nahrálo zlomek vteřiny bez řeči a hodnocení ho uznalo jako správnou odpověď (chybějící skóre znamenalo 0,8). Teď se nahrávka kratší než 0,5 s nebo bez řeči nevyhodnocuje, zastavení počká na zapnutí mikrofonu a bez přepisu nebo skóre je odpověď špatně.

## 🛠️ Úpravy po ručním testu (7. 11. 2026)

Úpravy vzešly z lekce 22 (první test kartiček v hovoru, viz [plán výuky](docs/plan-vyuky.md), fáze 1).

- **Kontext po obnově spojení:** model na repliku neodpověděl a spojení se obnovilo, jenže student mezitím krátce promluvil. Ověření té repliky doběhlo až během obnovy a přepnulo stav z „reconnecting“ na „thinking“, takže agent nové spojení nepovažoval za obnovu a kontext mu neposlal. Tutor pak studenta znovu pozdravil. Obnovu teď agent pozná podle vlastního příznaku, ne podle stavu na displeji.
- **Opravný přepis se při zaseknutí přepne na další model:** jeden model měl na odpověď 20 s, stejně jako celý přepis. Když flash-lite neodpovídal, další model se už nezkusil a uložil se neúplný živý přepis (z 50 s řeči jen „Jak se řekne propojení?“). Teď má každý model 9 s.
- **Opravný přepis začíná flash-lite:** začínal `gemini-3.6-flash`, který má jen 20 požadavků denně. V lekci 22 došel po šesti minutách hovoru a rozbor po lekci pak při přetížení 3.8 Flash skončil na flash-lite, který udělal jednu špatnou kartičku. 3.6 Flash je teď poslední záloha přepisu.

## 🛠️ Úpravy po ručním testu (1. 11. 2026)

Úpravy vzešly z rozboru lekcí 17 a 18. Počet testů vzrostl z 409 na 416.

- **Zaseknutý tutor se vzpamatuje:** v lekci 18 model na repliku studenta neodpověděl. Server dál potvrzoval začátek a konec řeči, ale nepřepisoval ji a neodpovídal. Student se po 4–5 s ticha ozval znovu („Haló?“) a každá další replika vynulovala 11s lhůtu na odpověď. Lhůta tak nikdy nedoběhla a student lekci po minutě ukončil. Teď lhůta běží od první nezodpovězené repliky (viz *Jak funguje Gemini Live Audio Pipeline*, bod 4).
- **Tutor po obnově spojení odpoví:** v lekci 17 se po zaseknutí spojení obnovilo, ale kontext odešel s `turnComplete: false`. Tutor tedy čekal na studenta a student na tutora, dokud po 45 s nezasáhl watchdog. Když poslední replika studenta zůstala bez odpovědi, obnovený kontext teď končí pokynem `LiveTutorPrompts.answerAfterReconnect` a model hned odpovídá.
- **Kontext po každém vynuceném reconnectu:** obnova spojení kvůli limitu tokenů, signálu `goAway` nebo zacyklení na řídicích tokenech kontext hovoru neobnovovala. Nové spojení znalo jen systémový prompt a tutor se v lekci 18 zeptal „Would you like to continue the conversation in English?“. `GeminiLiveClient.forceReconnect` teď agentovi ohlásí výpadek stejně jako spadlé spojení. Agent pak po připojení kontext obnoví a obnovu započítá do „Reconnecty“ v souhrnu lekce (dřív tam byla 0, i když proběhly dvě).
- **Zbytečný druhý reconnect:** počítadlo tokenů se po novém spojení nevynulovalo a `turnComplete` se zpracoval dřív než `usageMetadata` ze stejné zprávy. Agent proto 20 s po první obnově spojení viděl ještě starých 25 701 tokenů a spojení obnovil znovu. Teď se počítadlo s každým spojením nuluje a spotřeba se zpracuje před koncem tahu.

---

## 🛠️ Úpravy po ručním testu (9.–11. 10. 2026)

Úpravy vzešly z rozboru logů hlasových lekcí z telefonu a z gramatického drilu. Počet testů vzrostl z 333 na 405.

- **Ukončení a spuštění lekce se nepřekříží:** start počká na rozběhnuté ukončení, a když lekci během spouštění někdo ukončí, hovor se nespustí. Dřív mohl hovor běžet bez lekce v databázi, takže se přepis neukládal ani nevyhodnotil.
- **Chyba spojení lekci uzavře:** po chybě (např. „Nepodařilo se obnovit spojení“) se lekce uloží a spustí se rozbor. Dřív zůstala otevřená a nevyhodnocená.
- **Ruční detekce řeči místo popostrčení:** po 2 s ticha aplikace dřív posílala prázdný `clientContent` s `turnComplete`. Ten dorazil dřív než přepis studenta a model odpověděl na prázdný tah („Take your time...“, nebo i 16 s mumlání přepsaného jako „...“). Náhrada přes `audioStreamEnd` řeč na serveru často neuzavřela vůbec: ve 14 pobídkách lekce 8 server 5× nereagoval a jednou to skončilo obnovením spojení. Serverová detekce řeči je teď vypnutá a začátek i konec řeči ohlašuje aplikace (viz *Jak funguje Gemini Live Audio Pipeline*, bod 4). Trpělivost učitele teď přímo určuje délku ticha (dřív se čekalo vždy aspoň 2 s).
- **Opravný přepis replik studenta:** viz *Jak funguje Gemini Live Audio Pipeline*, bod 5.
- **Chyby z minulých lekcí:** v promptu tutora byly zapsané jako „Řekl: …“ a tutor je na žádost o další opravy vydával za chyby z právě probíhajícího hovoru. Teď jsou v sekci *CHYBY Z MINULÝCH LEKCÍ* jako „V minulé lekci řekl: …“ a pravidlo *Opravuj jen tento hovor* určuje, že další opravy patří jen k replikám z tohoto hovoru.
- **Repliky bez slov:** tah tutora přepsaný jen jako „...“ se nezobrazí ani neuloží.
- **Pauza:** dokončený tah tutora ani přerušení pauzu nezruší. Zbytek rozpracované odpovědi se během pauzy nepřehraje.
- **Log lekce a nahlášení problému:** viz *Log z telefonu*.
- **Scroll vs. výběr textu tutora:** tah prstem přes text tutora dřív skoro vždy zapnul výběr fráze, protože výběr se zapínal po 8 px do strany nebo po přejetí na sousední slovo, tedy dřív než scroll (18 px). Teď tah vždycky scrolluje. Klepnutí na slovo ho přeloží a frázi označí podržení slova (`kLongPressTimeout`) a tažení. Rozpoznávač je v `tutor_text_selection_recognizer.dart`.
- **Kartička až na přání:** překlad se do kartiček uloží tlačítkem „+ Uložit“, ne hned po otevření. Rovnou se uloží jen slovíčko vybrané z přeložené věty a rozšířená fráze, pokud byla předchozí fráze uložená.
- **Čeština nejde označit:** `tokenizeTutorText` (`tutor_text_tokens.dart`) dělí text na úseky. Každý tučný či kurzivní text a každé uvozovky jsou samostatný úsek, zbytek věty tvoří jeden úsek. Úsek se dvěma českými slovy, nebo s převahou českých slov, je obyčejný text. Anglický příklad v tučném textu nebo v uvozovkách uvnitř české věty jde označit. Tučný text přes víc slov se zobrazí bez hvězdiček.
- **Čistý překlad:** model občas vrátí v překladu zbytek formátování, např. „Jak to, že</code>“. `WordTranslationService.cleanTranslationText` z odpovědi odstraní HTML/XML tagy, markdown a uvozovky. Stejně se vyčistí i starší záznamy v mezipaměti překladů při jejím načtení.
- **Bublina „Tutor vyhodnocuje…“ v drilu** na úzkém displeji (360 dp) přetékala o 24 px. Text se teď zalomí.
- **Rub kartičky:** slovíčko uložené z překladu mělo jako „Nápovědu a vysvětlení“ jen větu tutora („Z věty tutora: …“), a ta se na rubu ukázala ještě jednou. Teď se ukládá bez vysvětlení. Rub ukazuje „Vysvětlení“: krátké české vysvětlení výrazu, které při prvním opakování připraví Gemini (`CardExplanationResolver`) a uloží ho ke kartičce. Stejně se doplní i starší kartičky se zástupným textem. Původní věta zůstává dole a slova z kartičky jsou v ní podtržená (`highlightRanges` v `sentence_highlight.dart` najde celý výraz, nebo jednotlivá slova i v běžných tvarech jako *takes* nebo *taking*).

---

## 🛠️ Úpravy po ručním testu (2. 10. 2026)

Úpravy vzešly z prvního testu na telefonu. Počet testů vzrostl z 321 na 333.

- **Příprava tématu při startu:** `TopicPreparationAgent` se spouštěl dřív, než se z úložiště načetl API klíč. Při startu aplikace proto nikdy nepřipravil téma a v logu bylo „Chybí API klíč, přeskočeno“. Teď `SkeletonScreen` čeká na načtení klíče. Agent si navíc před kontrolou čerstvosti načte uložené téma z databáze, aby zbytečně nevolal Gemini.
- **Kartičky bez proklikávání:** kartička se otočí až po pokusu o odpověď. Odpovědět jde hlasem, napsáním (`AnswerInputBar`), nebo tlačítkem „Nevím – ukázat řešení“. Po „Nevím“ jde dát jen „Znovu“. Napsanou odpověď porovnává `TypedAnswer` přímo v telefonu bez AI (Levenshteinova vzdálenost) a podle shody zvýrazní doporučené hodnocení. Porovnává se jen podle písmen, takže synonymum dostane nízké skóre.
- **Více chyb v jedné větě:** tutor z jedné promluvy vybere nejvýš dvě nejdůležitější chyby a opraví je postupně, vždy jednu za tah a bez další otázky. K tématu se vrátí až potom. Drobnosti nechá na rozbor po lekci.
- **Tutor se neutíná:** rady režiséra, pokyn k odlehčení a tichá změna tématu se dřív posílaly kdykoliv a mohly tutora utnout uprostřed věty. Teď čekají na konec jeho tahu (viz *Jak funguje Gemini Live Audio Pipeline*, bod 5).
- **Přepis v cizím jazyce:** STT Gemini Live občas přepíše anglickou řeč do jiného jazyka (španělštiny, hindštiny…), i když model studentovi rozumí. Je to známá chyba na straně Google. Pro konverzační model se jazyk přepisu nastavit nedá, `languageCodes` podporuje jen `gemini-3.5-transcribe-live`. Bublina proto může ukázat nesmysl. Rozbor lekce takové repliky ignoruje. `MemoryManagerAgent` navíc neuloží chybu, jejíž text obsahuje ¿ ¡ ñ nebo nelatinkové písmo, aby z ní nevznikla kartička.
- **Log do souboru:** ladicí verze zapisuje výstup loggeru `L` i do `logs/latest.log` (viz *Kontrola změn*).

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
2. **`voice_tutor_agent.dart` má k 14. 11. už 2216 řádků** (po opravách z 9.–10. 10. měl 1562). Dalším krokem je vyčlenit do `services/agents/voice_tutor/` spuštění a ukončení lekce (`startSession` má asi 200 řádků, `stopSession` asi 120) a zpracování zvuku z mikrofonu (`_handleIncomingAudioChunk`, `_processAudioChunkForVAD` a časovače, asi 190 řádků). Dělat to až po úspěšném ručním testu. Jde o řízení živého hovoru a reálný zvuk automatické testy nepokryjí.
3. **Další soubory nad 600 řádků.** Rozdělit je, až se na nich bude pracovat:
   - `features/conversation/widgets/word_translation_sheet.dart` (756): překlad, uložení do kartiček a vrácení zpět přesunout ze stavu widgetu do controlleru. Metodu `build` (přes 400 řádků) rozdělit na menší widgety.
   - `services/gemini/gemini_live_client.dart` (737): zpracování zpráv ze serveru (`_handleIncomingMessage`, asi 190 řádků) přesunout do samostatného parseru. Klientovi zůstane připojení, reconnect a odesílání.
4. **Nepoužívaná `features/history/history_screen.dart` (smazáno 17. 11.).** Historie lekcí je v záložce Pokrok. Testy seznamu lekcí ověřují `LessonHistoryTab` (`test/features/progress/lesson_history_tab_test.dart`).
5. **Migrace databáze (zatím odloženo).** Opravy schématu a deduplikace kartiček v `beforeOpen` (`data/database/app_database.dart`) běží při každém startu aplikace. `schemaVersion` je od přidání tabulky `topic_history` (21. 11.) 5, nová tabulka vzniká v `onUpgrade` přes `createAll`. Doporučený postup: opravy z `beforeOpen` přesunout do `onUpgrade` a přidat test migrace na starší databázi. Změna se týká dat uložených v zařízení, proto zatím počkala.
6. **Kartičky smazané chybnou deduplikací se samy nevrátí.** Jejich chyby mají dál příznak `in_flashcard`, takže z nich nové kartičky nevzniknou a detail lekce u nich ukazuje, že už v kartičkách jsou. Příznaky by šlo vynulovat u chyb, ke kterým žádná kartička neexistuje. Tím by se ale vrátily i chyby záměrně vyřazené z generování a chyby, jejichž kartičky byly smazané ručně, proto to zatím neproběhlo.
7. **Zaseknutí modelu na serveru (příčina neznámá, aplikace se vzpamatuje).** Model po replice studenta přestane přepisovat i odpovídat, server jen dál potvrzuje začátek a konec řeči. V lekcích 17 a 18 to log zachytil celé. Aplikace serveru v tu chvíli neposílala nic neobvyklého, příčina je tedy nejspíš v Gemini Live. V lekci 17 se to stalo po třech minutách pauzy, v lekci 18 chvíli po přehrání výslovnosti (to jde přes REST, mimo Live spojení). Aplikace teď spojení obnoví a tutor odpoví (viz *Úpravy po ručním testu (1. 11. 2026)*). Kdyby se zaseknutí opakovalo často, stojí za to zkusit jiný Live model.
8. **Tutor občas pochválí špatně zopakovanou opravu**, např. „I will call.“ místo „I will code.“ → „Exactly!“. Nejspíš studenta špatně slyší. Zatím neřešeno.
9. **Diakritika v cestě k projektu.** Kvůli `Programování` v cestě nefunguje `flutter analyze`, `aapt` vypisuje chyby a AGP potřebuje `android.overridePathCheck=true` v `android/gradle.properties`. Přejmenováním složky na `Programovani` by všechny tyhle obcházky odpadly.
10. **Upgrade AGP a Kotlinu (hotovo).** Projekt je na AGP 9.1.0, Kotlinu 2.4.0 a Gradlu 9.3.1, tedy na verzích ze šablony Flutteru 3.47.5. Příznaky `android.newDsl=false` a `android.builtInKotlin=false` v `android/gradle.properties` zůstaly ze šablony.
11. **Plán vylepšení výuky** (kartičky v hovoru, režim Lekce, gramatický cíl lekce a další): [`docs/plan-vyuky.md`](docs/plan-vyuky.md).
12. **Souvislý hovor: session resumption a komprese kontextu (v kódu 12. 11., první test na telefonu 12. 11., výchozí od 17. 11.).** Dřív byly obě vypnuté kvůli modelu `gemini-3.1-flash-live-preview`: token pro obnovu při reconnectu způsoboval smyčku chyb 1007 a komprese byla v nastavení na špatném místě (v `generationConfig`). Teď jsou za přepínačem „Souvislý hovor“, od 17. 11. je výchozí stav zapnuto. Jak to funguje, je v oddílu *Jak funguje Gemini Live Audio Pipeline*, bod 7.
    - Podle dokumentace Live API (`aistudio.google.com/docs/live-api/session-management` a `aistudio.google.com/api-reference/live`, čteno 11. a 12. 11. 2026): `setup.sessionResumption` má jediné pole `handle`, server posílá `sessionResumptionUpdate` s `newHandle` a `resumable`, token platí 2 hodiny po konci spojení. `setup.contextWindowCompression` má `slidingWindow.targetTokens` a `triggerTokens` (výchozí 80 % kontextu modelu). Bez komprese je zvukové sezení omezené na 15 minut, spojení trvá kolem 10 minut a před koncem server pošle `goAway` s `timeLeft`. Co se stane s neplatným tokenem a jestli to celé platí i pro bezplatnou úroveň, dokumentace neříká.
    - Podle logů lekcí 8–26: spojení se zavřelo 13× (3× kód 1008 pro nečinnost, 2× kód 1002, 8× bez kódu), 5× se obnovilo kvůli 25 tisícům tokenů, 2× proto, že model neodpověděl, a 1× zasáhl watchdog. Zpráva `goAway` nepřišla ani jednou, ani v lekci dlouhé 37 minut. Souvislý hovor míří na těch 13 zavření a na limit tokenů.
    - První test na telefonu (lekce 28): server pole přijal a navázání po pauze funguje. Po výpadku sítě server navázání odmítá, dokud drží staré spojení (viz *Úpravy po lekci 28*). Komprese kontextu zasáhla v lekci 29 (viz tamtéž). Lekce 33 ověřila obojí, co zbývalo: s prahem 16 000 přišlo zkrácení třikrát kolem 20 tisíc tokenů (na 15–16 tisíc) a staré spojení po výpadku sítě server neuvolnil ani za 18 s, takže klient na něj už nečeká (viz *Úpravy po lekci 33*).
    - Pokyn `LiveTutorPrompts.answerAfterResume` neprošel testem promptu (`tool/prompt_eval/`). Je to obdoba `answerAfterReconnect` bez odkazu na shrnutí.
    - Od 17. 11. je souvislý hovor výchozí (dřív uložená volba v Nastavení platí dál). Zbývá zvážit zrušení obnovy spojení při 25 tisících tokenech. V lekci 33 se s kompresí spotřeba k té hranici nepřiblížila (nejvýš 20 450), shrnutí od režiséra zůstává jako záloha.
13. **Stavový automat hovoru a přehrávání logů lekcí.** `VoiceTutorAgent` řídí hovor tuctem příznaků (`_activityOpen`, `_awaitingResponse`, `_reconnectPending`, `_openerDue`…) vedle stavu na displeji a velká část oprav v tomto souboru jsou souběhy a pořadí událostí mezi nimi. Navazuje to na bod 2: místo dělení jen podle délky vytáhnout řízení tahů do automatu v čistém Dartu (události dovnitř, akce ven, bez Riverpodu a bez hodin). Log lekce (`session_<id>.log`) obsahuje čas i všechny události, takže by šel převést na vstup automatu a každá nahlášená lekce by se stala regresním testem.
14. **Release build pro denní používání.** Log do souboru a řádky `[VAD]` a `[DEBUG]` jsou vázané na `kDebugMode`, proto na telefonu běží ladicí verze, která je pomalejší než ostrá. Detekce řeči a časování se tak ladí na jiné rychlosti, než jakou bude mít ostrá verze. Log by šel zapínat nastavením a sdílet z detailu lekce (`share_plus` v projektu je), odpadlo by i stahování přes adb.
15. **Kontroly v CI (hotovo 12. 11., první běh na GitHubu ještě neproběhl).** Pravidla struktury hlídá `test/architecture_test.dart` a `.github/workflows/ci.yml` pouští `dart analyze lib test` a `flutter test` při každém pushi. Do 11. 11. v pracovní větvi jeden test padal, aniž by si toho kdo všiml. Workflow počítá s Flutterem 3.47.5 na Ubuntu; balíček `sqlite3` si tam knihovnu sestavuje sám, takže první běh ukáže, jestli runneru něco nechybí.
16. **Drobnosti z revize 11. 11.:**
    - Kód pro volání funkcí (`toolCall` v `GeminiLiveClient`, `_onToolCall` v agentovi) odstraněn (hotovo 17. 11.).
    - Odchod z aplikace během hovoru ho pozastaví (hotovo 17. 11.).
    - Export zálohy přepsán na zálohovací API SQLite stejně jako obnova (hotovo 17. 11.).
    - Adresa spojení s Gemini Live má klíč dál v parametru `key=` (v logu je maskovaný). Jestli server přijme klíč i v hlavičce, dokumentace neříká.
17. **`gemini-3.8-flash` od 7. 11. neodpovídá (ověřeno 24. 11.).** V logu je od 7. do 14. 11. šestnáct pokusů a neuspěl žádný. Kontrola 24. 11. na Free Tier klíči potvrdila: `gemini-4-neon`, `gemini-4-carbon`, `gemini-4-argon`, `gemini-omni-1.2-flash` a `gemini-3.1-pro-preview` mají na Free Tier `limit: 0` (429); `gemini-4-hydrogen`, `gemini-3.8-flash`, `gemini-3.6-flash`, `gemini-3.1-flash-lite` i `gemma-4-*` vracely 503; spolehlivě na Free Tier odpovídají `gemini-3.5-flash-lite`, `gemini-decision-1` a `gemini-3.8-live`. Zpětné zařazení témat proto od 24. 11. začíná na `flash-lite`. Zbývá případně uložit cooldown přes restart aplikace.
18. **Detekce krátkých odpovědí prakticky nikdy nezasáhne (opraveno 17. 11.).** Podmínka ve `_flushUserTranscript` nyní kontroluje délku skutečné řeči (`utterance.voicedMs >= 3000`) místo `audioMs` (které zahrnovalo i 2 s ticha a úvod z `PreRollBuffer`). Zbývá ověřit chování v praxi na telefonu / testem promptu.
19. **Jednoslovná kartička splněná jiným slovním druhem (hotovo 17. 11.).** Jednoslovné cíle v pokecu se nesplní jen doslovnou shodou, ale ověří je rozhodčí (`LessonCardJudge`) podle významu a slovního druhu.
20. **Detekce opakování tutora zasahuje, i když se tutor opakovat má (hotovo 17. 11.).** `repeatedTurnSimilarity` nyní zasáhne, až když se promluva tutora podobá aspoň dvěma z posledních tří promluv v historii (`minMatches = 2`), tedy až když se tutor opakuje potřetí.
21. **Opravný přepis si z krátkých útržků vymýšlí věty (lekce 36 a 38).** Z 0,2–0,5 s zvuku (začátek repliky, klepnutí na slovo) vznikly čtyřikrát za večer celé česko-anglické věty („I went to the park, ale nevím, jestli will be open.“). Pojistka `fitsVoicedTime` je zatím zahodila, kratší výmysl by ale prošel. Prompt přepisovače upravit a ověřit na nahrávkách, ne naslepo.
22. **Útržek zvuku před pauzou zůstává rozpracovanou replikou.** Při klepnutí na slovo (překlad pozastaví hovor) mikrofon zachytí krátký zvuk a po obnovení se ověřuje jako replika (lekce 38). Zvážit, jestli při pauze nezahodit repliku kratší než 700 ms, kterou server ještě nedostal.
23. **Evidence témat na telefonu (doladěno 24. 11.).** Backfill v `latest.log` z 24. 11. selhal kvůli 503 na `3.8-flash` / `3.6-flash`, takže `topic_history` byla na telefonu prázdná a plánovač chybně nabízel všechny oblasti jako nové. Od 24. 11. backfill začíná na `flash-lite` a `loadTopicPlan` při prázdné evidenci před dokončeným backfillem vrací prázdný plán. Zbývá ověřit na telefonu po dalším spuštění (řádek „Evidence témat doplněna“ v logu).
24. **Režisér se ve scénáři zavrtal do drobností a opakoval rady (opraveno 24. 11.).** V lekci 38 režisér poslal 4 téměř stejné rady o policích do sklepa za sebou, protože neznal své předchozí rady ani kontext scénáře. Od 24. 11. režisér dostává `scenarioContext` i `recentWhispers` a má zakázáno opakovat obměny téže otázky.
