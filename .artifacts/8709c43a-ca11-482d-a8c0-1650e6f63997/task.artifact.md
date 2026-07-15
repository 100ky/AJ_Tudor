# Úkoly pro implementaci 3. agenta a vylepšení architektury

- [x] `[x]` **Fáze 1: Příprava infrastruktury a promptů**
    - [x] `[x]` Aktualizace `pubspec.yaml` (přidání `flutter_secure_storage`)
    - [x] `[x]` Refaktorizace `SystemPromptBuilder` (definice schémat a bilingvního protokolu)
    - [x] `[x]` Úprava `GeminiBatchClient` pro podporu Structured Outputs
    - [x] `[x]` Úprava `GeminiLiveClient` pro podporu Function Calling

- [x] `[x]` **Fáze 2: Refaktorizace Memory Manageru**
    - [x] `[x]` Implementace Structured Outputs v `MemoryManagerAgent`
    - [x] `[x]` Odstranění regexů a manuálního čištění JSONu

- [x] `[x]` **Fáze 3: Nový Scenario Planner Agent**
    - [x] `[x]` Vytvoření `ScenarioPlannerAgent`
    - [x] `[x]` Implementace logiky pro výběr scénářů z DB
    - [x] `[x]` Integrace spouštění po analýze Memory Managerem

- [x] `[x]` **Fáze 4: Vylepšení Voice Tutora**
    - [x] `[x]` Implementace `log_error` toolu ve `VoiceTutorAgent`
    - [x] `[x]` Dynamická injekce zvoleného scénáře do system promptu

- [x] `[x]` **Fáze 5: Bezpečnost a UI**
    - [x] `[x]` Migrace `ApiKeyNotifier` na `flutter_secure_storage`
    - [x] `[x]` Implementace mizejících titulků ve `VoiceTutorScreen`
    - [x] `[x]` Přidání kartiček scénářů na `ConversationScreen`

- [x] `[x]` **Fáze 6: Verifikace**
    - [ ] `[ ]` Manuální testování hlasové session a chyb
    - [ ] `[ ]` Kontrola bezpečného uložení klíčů
