# Walkthrough - 3. Agent a Architektonické vylepšení

V rámci této aktualizace byla do aplikace AJ Tudor implementována pokročilá architektura se třemi agenty, zvýšena bezpečnost ukládání dat a vylepšeno UI pro pohlcující výuku.

## Hlavní změny

### 1. Scenario & Curriculum Planner (3. Agent)
- **Nový agent**: [ScenarioPlannerAgent](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/scenario_planner_agent.dart) asynchronně generuje 3 personalizované Role-Play scénáře.
- **Personalizace**: Scénáře jsou tvořeny na základě historie chyb, zájmů uživatele a aktuální slovní zásoby z databáze.
- **Integrace**: Scénáře se zobrazují jako interaktivní kartičky na hlavní obrazovce. Po kliknutí se scénář "vštípí" do Voice Tutora jako specifický kontext.

### 2. Structured Outputs & JSON Schema
- **Memory Manager**: Přechod na nativní Structured Outputs. Již žádné nespolehlivé regexy nebo parsování Markdownu.
- **Robustnost**: [SystemPromptBuilder](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/prompt/system_prompt_builder.dart) nyní definuje přesná JSON schémata pro analýzu i plánování.

### 3. Real-time Logování Chyb (Function Calling)
- **Voice Tutor**: Implementována podpora pro **Function Calling** v Gemini Live API.
- **log_error**: Model nyní během plynulé řeči paralelně volá funkci `log_error`, která okamžitě zapisuje chyby do SQLite, aniž by přerušila hovor.

### 4. Bezpečnost (Secure Storage)
- **API Key**: Přechod ze `SharedPreferences` na `flutter_secure_storage` (Android Keystore).
- **Migrace**: Implementována automatická migrace klíče ze starého úložiště do šifrovaného.

### 5. UI/UX Vylepšení
- **Ambient Mode**: Vylepšené slábnutí starších zpráv v historii (kinetic transcription), aby se student mohl soustředit na přítomný okamžik.
- **Scenario Cards**: Nová sekce doporučení na hlavní obrazovce.
- **Bilingvní Protokol**: Voice Tutor nyní striktněji dodržuje protokol (vysvětlení česky -> oprava anglicky -> doplňující otázka).

## Verifikace

> [!TIP]
> **Vyzkoušejte**:
> 1. Na hlavní obrazovce klikněte na "Vygenerovat scénáře na míru".
> 2. Vyberte si scénář a přejděte do sekce Voice.
> 3. Spusťte hovor a udělejte úmyslnou chybu (např. "I has a car").
> 4. Zkontrolujte v sekci Progress, zda byla chyba okamžitě zalogována.

 render_diffs(file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/memory_manager_agent.dart)
 render_diffs(file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/prompt/system_prompt_builder.dart)
 render_diffs(file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart)
 render_diffs(file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/config_provider.dart)
