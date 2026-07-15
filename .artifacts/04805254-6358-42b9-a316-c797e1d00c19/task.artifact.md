# Úkoly pro implementaci vylepšení AJ Tudor

- [x] **Zabezpečení proti Prompt Injection**
    - [x] Aktualizovat `buildAnalysisPrompt` v `system_prompt_builder.dart`
- [x] **Dynamický Waveform Visualizer**
    - [x] Optimalizovat výpočet hlasitosti v `audio_capture_service.dart`
    - [x] Vylepšit organické vykreslování v `waveform_visualizer.dart`
- [x] **Kinetická transkripce (Mizející titulky)**
    - [x] Implementovat `ShaderMask` pro efekt slábnutí v `voice_tutor_screen.dart`
    - [x] Upravit logiku zobrazení transkriptu pro 2-3 věty
- [x] **Upozornění a připomínky (Reminders)**
    - [x] Přidat `flutter_local_notifications` a `timezone` do `pubspec.yaml`
    - [x] Implementovat `NotificationService` v `lib/services/notifications/notification_service.dart`
    - [x] Přidat nastavení do `config_provider.dart`
    - [x] Upravit `SettingsScreen` v `settings_screen.dart`
    - [x] Inicializovat službu v `main.dart`
- [x] **Verifikace**
    - [x] Manuální test vizualizace a titulků
    - [x] Kontrola promptů
    - [x] Test funkčnosti upozornění
