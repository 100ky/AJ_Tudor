# Implementace upozornění (Reminders) pro trénink

Tento plán pokrývá přidání systému lokálních upozornění, která budou uživatele motivovat (nebo „otravovat“) k pravidelnému procvičování angličtiny.

## User Review Required

> [!IMPORTANT]
> Pro funkčnost upozornění bude nutné přidat nové závislosti (`flutter_local_notifications` a `timezone`) a provést základní konfiguraci pro Android/iOS.
> Uživatel bude mít možnost nastavit „Otravný režim“ (Annoying Mode), který bude posílat upozornění častěji.

## Proposed Changes

### [Závislosti] pubspec.yaml

#### [MODIFY] [pubspec.yaml](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/pubspec.yaml)
*   Přidání `flutter_local_notifications: ^17.2.2` (nebo nejnovější stabilní).
*   Přidání `timezone: ^0.9.4` pro plánování v konkrétní čas.

---

### [Služby] Notification Service

#### [NEW] [notification_service.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/services/notifications/notification_service.dart)
*   Inicializace `flutter_local_notifications`.
*   Metody pro plánování denních upozornění.
*   Logika pro „Otravný režim“ (plánování více upozornění během dne).
*   Seznam vtipných/motivačních zpráv v češtině i angličtině (např. „Don't forget your English! Gemini is lonely.“).

---

### [Providers] Konfigurace

#### [MODIFY] [config_provider.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/providers/config_provider.dart)
*   Přidání `remindersEnabledProvider`.
*   Přidání `annoyingModeProvider`.
*   Přidání `reminderTimeProvider` (uložení preferovaného času).

---

### [UI] Nastavení

#### [MODIFY] [settings_screen.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/features/settings/settings_screen.dart)
*   Přidání nové sekce „Upozornění a připomínky“.
*   Switch pro zapnutí/vypnutí.
*   Switch pro „Otravný režim“.
*   TimePicker pro výběr času hlavního upozornění.

---

### [Init] main.dart

#### [MODIFY] [main.dart](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/lib/main.dart)
*   Inicializace `NotificationService` při startu aplikace.

## Verification Plan

### Automated Tests
*   Ověření kompilace po přidání závislostí.

### Manual Verification
*   Zapnutí upozornění v nastavení a nastavení času na „za minutu“.
*   Ověření, že upozornění dorazí (i když je aplikace na pozadí).
*   Ověření funkčnosti „Otravného režimu“ (vizuální kontrola naplánovaných časů v logu).
