# AJ Tudor – Kompletní analýza kódu a plán oprav

Provedl jsem důkladnou analýzu celého projektu (30+ souborů). Níže je souhrn toho, co **funguje dobře**, co **chybí**, a co **je špatně**.

---

## ✅ Co funguje dobře (solidní základ)

| Oblast | Stav |
|---|---|
| Multi-agentní architektura (3 agenti) | ✅ Správně oddělené zodpovědnosti |
| Drift (SQLite) databáze + 5 tabulek | ✅ Tabulky, migrace, typová bezpečnost |
| SessionRepository (čisté API) | ✅ Result pattern, error handling |
| GeminiLiveClient (WebSocket + reconnect) | ✅ Exponenciální backoff, session resumption |
| GeminiBatchClient (waterfall fallback) | ✅ Kaskádový fallback přes 3 modely |
| Audio capture/playback (PCM 16-bit) | ✅ Správné formáty 16kHz/24kHz |
| SystemPromptBuilder (bilingvní pedagogika) | ✅ Immersive/Teacher mode, adaptivní úrovně |
| Function Calling (log_error) | ✅ Real-time logování chyb |
| Riverpod state management | ✅ Konzistentní použití |
| Secure Storage pro API klíč | ✅ Migrace ze SharedPreferences |
| UI skeleton s 6 záložkami | ✅ IndexedStack |
| Agents Screen (vizualizace 3 agentů) | ✅ Stavy, metriky, scénáře |
| Role-play scénáře (generování + výběr) | ✅ Funguje dobře |

---

## 🔴 Kritické problémy nalezené v kódu

### 1. Voice chat nenavazuje na historii – **HLAVNÍ BUG**

> [!CAUTION]
> **Problém, který popisuješ**: Každý voice chat je "od nuly" a opakuje se.

**Příčina**: V [voice_tutor_agent.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart#L220-L239) se sice načítá `lastBriefing` z DB a přidá se k promptu, ALE:

1. **ScenarioPlannerAgent se NEVOLÁ před zahájením chatu** – volá se jen *po skončení* lekce v `MemoryManagerAgent.analyzeSession()` (řádek 110). Voice Tutor se tedy **nikdy neptá plánovače**, o čem se bavit.
2. **Briefing je jen holý text** – nepřidávají se konkrétní **opakující se chyby** (`recurringErrors`), **slovíčka** (`vocabulary`) ani **zájmy** (`topicPreferences`) z profilu do systémového promptu.
3. **Kontext je příliš slabý** – prompt dostane jen generický "briefing", ale chybí strukturovaný kontext typu: *"Student má problém s Present Perfect. Probírali jsme cestování do Japonska. Zná slovíčka: luggage, boarding pass, customs."*

### 2. Model si začne povídat sám se sebou – **ZASEKNUTÍ**

**Příčina**: Několik propojených problémů v [voice_tutor_agent.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart):

1. **Audio se posílá jen ve stavu `listening`** (řádek 257), ale po `turnComplete` se stav mění na `listening` a audio jde znovu. Problém je, že pokud model **nepošle `turnComplete`** (chyba API), zůstáváme ve stavu `speaking` navždy.
2. **Stuck timer (10s)** existuje (řádek 501-511), ale jen vrátí do `listening` – **neřeší situaci, kdy model generuje sám odpovědi na sebe** (echo loop).
3. **Chybí ochrana proti echo loop**: Pokud model mluví a zároveň mikrofon zachytí jeho vlastní řeč z reproduktoru, pošle ji zpět do API → model na ni reaguje → nekonečná smyčka.

### 3. Chybí tlačítko PAUSE/RESUME – jen tvrdý Stop

V [voice_tutor_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart#L200-L221):
- Existuje **pouze jedno tlačítko**: buď `startSession()` nebo `stopSession()`.
- **`stopSession()` ukončí celé sezení**: zavře WebSocket, zastaví mikrofon, spustí analýzu.
- **Chybí stav `paused`** a logika pro pozastavení/obnovení.

### 4. Agenti se potenciálně "perou"

> [!WARNING]
> Ty 3 agenty máš dobře navržené a **neperou se** – ALE jenom proto, že ScenarioPlannerAgent se volá jen po skončení lekce. Problém je v tom, že:

1. **MemoryManager** a **ScenarioPlanner** běží sekvenčně (řádek 110 v `memory_manager_agent.dart`) – to je OK.
2. **ALE** v `conversation_screen.dart` (řádek 92) si uživatel může kliknout na "Vygenerovat scénáře" i **během** probíhající lekce – to by mohlo způsobit race condition se zápisem do DB.
3. **Voice Tutor se neptá plánovače** – jak zmíněno v bodu 1.

### 5. Textový chat nevyužívá historii / netrénuje gramatiku

V [conversation_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/conversation_screen.dart):
- Chat je **jednorázový** – neukládá se do DB, neanalyzuje se.
- **Nenavazuje na voice historii** – neporadí se s Memory Managerem.
- **Chybí gramatický drill režim** – měl by vycházet z `recurringErrors` profilu.

### 6. Chybí textový input pro vlastní téma

Popisuješ požadavek: *"textový label kde stručně napíšu o čem by téma mělo být a AI by ho doladila"*. Toto v kódu **vůbec neexistuje**.

---

## 🟡 Menší problémy a chybějící kusy

| # | Problém | Soubor |
|---|---|---|
| 7 | `gemini-3.5-flash` nemusí být platný název modelu pro Live API | [gemini_models.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/core/constants/gemini_models.dart) |
| 8 | `audioPlaybackServiceProvider` v `onDispose` volá `stop()` místo `dispose()` – únik `StreamController` | [audio_provider.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/audio_provider.dart#L13) |
| 9 | `_textController` ve `voice_tutor_screen.dart` se vytváří ale **nikdy nepoužívá** (mrtvý kód) | [voice_tutor_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart#L15) |
| 10 | `profile_provider.dart` existuje ale nepoužívá se nikde (mrtvý soubor) | [profile_provider.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/profile_provider.dart) |
| 11 | `ChatMessage` třída je definovaná ve dvou souborech – **duplicita**: `conversation_screen.dart` (L11-14) i `voice_tutor_agent.dart` (`LiveChatMessage`, L38-46) | – |
| 12 | Scénář se po výběru neoznačí jako `isUsed` v DB – zůstává navěky v seznamu | [conversation_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/conversation_screen.dart#L196) |
| 13 | `_thinkingTimer` se inicializuje ale nikdy se nespouští (mrtvý kód) | [voice_tutor_agent.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart#L99) |

---

## Navrhované změny

### Fáze 1: Oprava historie voice chatu (kritické)

#### [MODIFY] [voice_tutor_agent.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart)
- **Před zahájením session** zavolat `ScenarioPlannerAgent` (nebo aspoň načíst existující scénáře) a konzultovat historii.
- Do systémového promptu přidat **strukturovaný kontext** z DB: `recurringErrors`, `vocabulary`, `topicPreferences`, nedávná témata.
- Přidat nový stav `TutorState.paused` a metody `pauseSession()` / `resumeSession()`.
- Přidat ochranu proti echo loop (ignorovat audio pod prahem hlasitosti, nebo pozastavit mikrofon když model mluví).
- Odstranit mrtvý `_thinkingTimer`.

#### [MODIFY] [system_prompt_builder.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/prompt/system_prompt_builder.dart)
- Rozšířit `buildTutorPrompt()` o parametry: `recurringErrors`, `vocabulary`, `recentTopics`.
- Přidat do promptu sekci s konkrétními daty z profilu, ne jen generický briefing.

---

### Fáze 2: Pause/Resume tlačítko

#### [MODIFY] [voice_tutor_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart)
- Přidat druhé tlačítko (Pause) vedle stávajícího Stop.
- Při pauze: zastavit mikrofon, ale **neukončovat** WebSocket ani session.
- Při resume: znovu aktivovat mikrofon a pokračovat.

---

### Fáze 3: Textový input pro vlastní téma

#### [MODIFY] [agents_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/agents/agents_screen.dart)
- Přidat `TextField` do sekce "Plánovač témat", kde uživatel stručně napíše o čem by téma mělo být.
- AI (ScenarioPlannerAgent) pak téma doladí a vytvoří z něj scénář.

#### [MODIFY] [scenario_planner_agent.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/scenario_planner_agent.dart)
- Přidat metodu `planCustomScenario(String userHint)` – generuje 1 scénář z uživatelova popisu.

---

### Fáze 4: Gramatický trénink v textovém chatu

#### [MODIFY] [conversation_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/conversation_screen.dart)
- Přidat přepínač "Gramatický drill" – chat začne trénovat přesně ty chyby, které jsou v profilu (`recurringErrors`).
- Ukládat chat do DB (nový typ session `text`).
- Využívat historii z voice chatu.

---

### Fáze 5: Oprava drobností a duplicit

#### [MODIFY] [audio_provider.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/audio_provider.dart)
- Opravit `onDispose` – volat `dispose()` místo `stop()`.

#### [DELETE] nebo [MODIFY] [profile_provider.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/profile_provider.dart)
- Smazat nepoužívaný soubor, nebo integrovat.

#### [MODIFY] [voice_tutor_screen.dart](file:///c:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart)
- Odstranit nepoužívaný `_textController`.

#### [MODIFY] Scénář výběr
- Po výběru scénáře volat `repo.markScenarioUsed(id)`.

---

## Otevřené otázky pro tebe

> [!IMPORTANT]
> 1. **Pause tlačítko** – chceš aby při pauze zůstal WebSocket otevřený (rychlé obnovení, ale žere API minuty), nebo ho zavřít a při resume znovu navázat přes Session Resumption handle?
> 2. **Vlastní téma** – chceš to textové pole jen na Agents screenu, nebo i přímo na Voice screenu?
> 3. **Gramatický drill** – chceš to jako oddělený mód v textovém chatu (přepínač), nebo jako novou záložku v navigaci?
> 4. **Echo loop ochrana** – preferuješ jednoduché řešení (mute mikrofonu když model mluví) nebo sofistikovanější (analýza hlasitosti + AEC)?

## Plán verifikace

### Automatické testy
```bash
flutter analyze
flutter test
```

### Manuální verifikace
- Build na Android emulátor / reálné zařízení
- Test voice chatu s historií (2 po sobě jdoucí session)
- Test pause/resume
- Test vlastního tématu
- Test gramatického drillu
