# Projekt Tudor - Architektonické vylepšení a 3. Agent

Tento plán detailně popisuje implementaci vylepšení pro aplikaci AJ Tudor, včetně zavedení 3. agenta (Scenario Planner), refaktorizace analýzy na Structured Outputs a zvýšení bezpečnosti i UX.

## User Review Required

> [!IMPORTANT]
> **API Key Security**: Přechod na `flutter_secure_storage` změní způsob ukládání API klíče. Stávající klíč uložený v `SharedPreferences` bude po aktualizaci zapomenut a uživatel jej bude muset zadat znovu (nebo implementujeme jednorázovou migraci).
> **Změna Promptů**: Sjednocení promptů do `SystemPromptBuilder` může mírně změnit chování agentů, pokud stávající inline prompty obsahovaly specifické nuance, které nejsou v builderu.

## Open Questions

- Chceme implementovat automatickou migraci API klíče ze `SharedPreferences` do `flutter_secure_storage`, nebo je v pořádku požádat uživatele o znovuzadání?
- Scénáře (Scenario Planner) by se měly generovat při každém startu aplikace, nebo jen po analýze nové lekce?

## Proposed Changes

### 1. Jádro a Prompty

#### [MODIFY] [system_prompt_builder.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/prompt/system_prompt_builder.dart)
- Sjednocení všech promptů.
- Definice JSON Schema pro `MemoryManagerAgent` a `ScenarioPlannerAgent`.
- Vylepšení `TutorPrompt` o bilingvní pedagogický protokol a ochranu proti prompt injection.

### 2. Agenti

#### [MODIFY] [memory_manager_agent.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/memory_manager_agent.dart)
- Přechod na nativní **Structured Outputs** (JSON Schema).
- Odstranění manuálního parsování a regexů.
- Použití promptu ze `SystemPromptBuilder`.

#### [NEW] [scenario_planner_agent.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/scenario_planner_agent.dart)
- Implementace 3. agenta.
- Logika pro generování 3 personalizovaných scénářů (Role-Play) na základě historie chyb, zájmů a slovní zásoby.

#### [MODIFY] [voice_tutor_agent.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/agents/voice_tutor_agent.dart)
- Implementace **Function Calling** (`log_error`) pro real-time zachycení chyb.
- Integrace scénářů do startu session.

### 3. Síť a API

#### [MODIFY] [gemini_live_client.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/gemini/gemini_live_client.dart)
- Podpora pro `tools` a `tool_calls` v Gemini Live API.
- Callback pro zachycení volání funkcí.

#### [MODIFY] [gemini_batch_client.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/gemini/gemini_batch_client.dart)
- Podpora pro `responseMimeType` a `responseSchema`.

### 4. Bezpečnost

#### [MODIFY] [config_provider.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/config_provider.dart)
- Nahrazení `shared_preferences` balíčkem `flutter_secure_storage` pro API klíč.

### 5. UI/UX

#### [MODIFY] [voice_tutor_screen.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/conversation/voice_tutor_screen.dart)
- Implementace kinetické transkripce (mizející titulky).
- Zobrazení aktuálně zvoleného scénáře.

#### [MODIFY] [skeleton_screen.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/skeleton/skeleton_screen.dart)
- Zobrazení kartiček se scénáři na úvodní obrazovce.

## Verification Plan

### Automated Tests
- `flutter test` pro ověření parsování JSON výstupů.
- Unit testy pro `SystemPromptBuilder` (ověření struktury schémat).

### Manual Verification
- Spuštění hlasové session a simulace chyby pro ověření `log_error` (Function Calling).
- Kontrola, zda se vygenerované scénáře správně propisují do system promptu.
- Ověření, že se API klíč ukládá bezpečně (kontrola logů a úložiště).
