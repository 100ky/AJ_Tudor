# AJ Tudor – Screen Lock, Lifecycle & History Implementation

Tento plán řeší automatické zamykání obrazovky, obnovení po odemknutí a chybějící implementaci Historie konverzací.

## Uživatelský přehled (User Review Required)

> [!IMPORTANT]
> **Historie**: Nově uvidíte seznam všech svých předchozích konverzací (lekcí) včetně shrnutí témat a dosažené plynulosti. Po rozkliknutí uvidíte celý přepis (transcript).

> [!NOTE]
> **Wakelock**: Obrazovka nezhasne pouze během aktivního hlasového hovoru.

## Navrhované změny

### [Core] Závislosti
- [MODIFY] [pubspec.yaml](file:///c:/Users/tosma/Desktop/Aj_Tudor/pubspec.yaml): Přidání `wakelock_plus` a `intl` (pro formátování dat v historii).

### [Features] History
- [MODIFY] [history_screen.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/lib/features/history/history_screen.dart):
    - Kompletní implementace s využitím `StreamBuilder` a `SessionRepository`.
    - Zobrazení seznamu karet (sessions) s datem, tématem a plynulostí.
    - Dialog nebo nová obrazovka pro zobrazení detailního přepisu lekce.

### [Services] Voice Tutor Agent
- [MODIFY] [voice_tutor_agent.dart](file:///c:/Users/tosma/Desktop/Aj_Tudor/lib/services/agents/voice_tutor_agent.dart):
    - Integrace `WakelockPlus`.
    - Sledování životního cyklu (`AppLifecycleState`) pro automatický reconnect po probuzení telefonu.

---

## Plán ověření

### Manuální ověření
1. **Historie**: Přejít na tab History, ověřit, že se zobrazují minulé lekce a lze zobrazit jejich detail.
2. **Wakelock**: Ověřit, že se telefon během hovoru nezamkne.
3. **Resume**: Zamknout telefon během hovoru, po chvíli odemknout a ověřit, že se aplikace pokusí o reconnect.
