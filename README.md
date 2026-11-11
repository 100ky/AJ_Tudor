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
│   ├── repositories/      # Repozitáře: lekce, profil studenta, scénáře, kartičky
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
    └── system/            # Wakelock, záloha databáze
```

### Pravidla struktury
- Závislosti vedou jedním směrem: `features → services → data → core`. Nižší vrstva nikdy neimportuje vyšší.
- Aplikace má jen tmavý vzhled („Noční studio“). Barvy a písmo berte z `AppTheme` (`AppTheme.font`, `textPrimary`, `surface`…), sdílené prvky z `core/widgets/`. Obsah patří do skupin řádků (`GroupedSection`), ne do samostatných barevných karet. Barva jen pro význam: stav hlasové vlny a lepší/horší u čísel. Ikona ovládacího prvku má vždy popisek nebo `tooltip`.
- Widgety nevolají AI ani nezapisují do databáze přímo. Jde to přes controller ve složce obrazovky, přes službu nebo přes agenta. Data z databáze čtou přes `StreamProvider`y v `data/data_providers.dart`.
- Soubor obrazovky jen skládá layout. Větší části patří do `widgets/`, akce do `*_controller.dart`.
- Provider služby leží ve stejném souboru nebo složce jako služba. Providery databáze, repozitářů a datových streamů jsou v `data/data_providers.dart`.
- Texty promptů jsou jen v `services/prompt/`.
- Volání Gemini REST API jdou přes `GeminiRestCore` (`services/gemini/gemini_rest_core.dart`). Jádro střídá modely, dává přetížené modely na cooldown a třídí chyby. Vlastní `Dio` jinde nevytvářejte.
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

---

## 🧪 Kontrola změn

Před každým commitem spusťte:

```bash
dart analyze lib test   # statická analýza
flutter test            # všechny testy, podrobnosti v test/README.md
```

Na cestě s diakritikou (např. `D:\Programování\…`) `flutter analyze` padá na chybě `FormatException`. `dart analyze` provede stejnou kontrolu a funguje. Ze stejného důvodu vypíše `flutter run` na začátku červené řádky od `aapt` (`Illegal byte sequence`, `Failed to extract manifest from APK`). Flutter si pak manifest vezme ze zdrojáků a aplikace se nainstaluje normálně.

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

### Test promptu tutora

Změny systémového promptu hlasového tutora se ověřují na skutečných replikách z lekcí přes `tool/prompt_eval/` (návod v `tool/prompt_eval/README.md`). Před změnou se uloží výchozí běh a po změně se porovná.

### Log z telefonu
Výpis z konzole je na sdílení obvykle moc dlouhý. Ladicí verze proto ukládá log i do souboru v úložišti aplikace. Stáhnete ho v Git Bash:

```bash
adb exec-out run-as com.tudor.aj_tudor cat app_flutter/logs/latest.log > latest.log
```

Každé spuštění aplikace začne nový `latest.log`, předchozí běh zůstane v `previous.log`.

Každá hlasová lekce má navíc vlastní log `logs/sessions/session_<id>.log`, který restarty aplikace přežije (drží se posledních 30 lekcí). Problém, který se v lekci projevil, jde popsat v detailu lekce tlačítkem „Nahlásit problém“, nebo dlouhým stiskem repliky, u které se projevil. Popis se uloží do tabulky `session_issues`. Postup rozboru je v `CLAUDE.md`.

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
- [ ] Záloha a import
- [ ] Reset paměti, jen pokud vám nevadí přijít o to, co si Tudor pamatuje

---

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
2. **`voice_tutor_agent.dart` má po opravách z 9.–10. 10. už 1562 řádků.** Dalším krokem je vyčlenit do `services/agents/voice_tutor/` spuštění a ukončení lekce (`startSession` má asi 200 řádků, `stopSession` asi 120) a zpracování zvuku z mikrofonu (`_handleIncomingAudioChunk`, `_processAudioChunkForVAD` a časovače, asi 190 řádků). Dělat to až po úspěšném ručním testu. Jde o řízení živého hovoru a reálný zvuk automatické testy nepokryjí.
3. **Další soubory nad 600 řádků.** Rozdělit je, až se na nich bude pracovat:
   - `features/conversation/widgets/word_translation_sheet.dart` (753): překlad, uložení do kartiček a vrácení zpět přesunout ze stavu widgetu do controlleru. Metodu `build` (přes 400 řádků) rozdělit na menší widgety.
   - `services/gemini/gemini_live_client.dart` (634): zpracování zpráv ze serveru (`_handleIncomingMessage`, asi 190 řádků) přesunout do samostatného parseru. Klientovi zůstane připojení, reconnect a odesílání.
4. **`features/history/history_screen.dart` se v aplikaci nepoužívá**, a to už před refaktoringem. Odkazují na ni jen testy, historie lekcí je v záložce Pokrok (oba seznamy kreslí stejný `SessionList`). Je potřeba rozhodnout, jestli ji smazat i s testem, nebo vrátit do navigace.
5. **Migrace databáze (zatím odloženo).** Opravy schématu a deduplikace kartiček v `beforeOpen` (`data/database/app_database.dart`) běží při každém startu aplikace. `schemaVersion` je od přidání tabulky `session_issues` 4. Doporučený postup: zvýšit ji na 5, opravy přesunout do `onUpgrade` a přidat test migrace na starší databázi. Změna se týká dat uložených v zařízení, proto zatím počkala.
6. **Kartičky smazané chybnou deduplikací se samy nevrátí.** Jejich chyby mají dál příznak `in_flashcard`, takže z nich nové kartičky nevzniknou a detail lekce u nich ukazuje, že už v kartičkách jsou. Příznaky by šlo vynulovat u chyb, ke kterým žádná kartička neexistuje. Tím by se ale vrátily i chyby záměrně vyřazené z generování a chyby, jejichž kartičky byly smazané ručně, proto to zatím neproběhlo.
7. **Zaseknutí modelu na serveru (příčina neznámá, aplikace se vzpamatuje).** Model po replice studenta přestane přepisovat i odpovídat, server jen dál potvrzuje začátek a konec řeči. V lekcích 17 a 18 to log zachytil celé. Aplikace serveru v tu chvíli neposílala nic neobvyklého, příčina je tedy nejspíš v Gemini Live. V lekci 17 se to stalo po třech minutách pauzy, v lekci 18 chvíli po přehrání výslovnosti (to jde přes REST, mimo Live spojení). Aplikace teď spojení obnoví a tutor odpoví (viz *Úpravy po ručním testu (1. 11. 2026)*). Kdyby se zaseknutí opakovalo často, stojí za to zkusit jiný Live model.
8. **Tutor občas pochválí špatně zopakovanou opravu**, např. „I will call.“ místo „I will code.“ → „Exactly!“. Nejspíš studenta špatně slyší. Zatím neřešeno.
9. **Diakritika v cestě k projektu.** Kvůli `Programování` v cestě nefunguje `flutter analyze`, `aapt` vypisuje chyby a AGP potřebuje `android.overridePathCheck=true` v `android/gradle.properties`. Přejmenováním složky na `Programovani` by všechny tyhle obcházky odpadly.
10. **Upgrade AGP a Kotlinu (hotovo).** Projekt je na AGP 9.1.0, Kotlinu 2.4.0 a Gradlu 9.3.1, tedy na verzích ze šablony Flutteru 3.47.5. Příznaky `android.newDsl=false` a `android.builtInKotlin=false` v `android/gradle.properties` zůstaly ze šablony.
11. **Plán vylepšení výuky** (kartičky v hovoru, režim Lekce, gramatický cíl lekce a další): [`docs/plan-vyuky.md`](docs/plan-vyuky.md).
