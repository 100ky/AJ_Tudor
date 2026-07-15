# TODO List - Odstranění Gradle varování

- [x] **Fáze 1: Gradle Konfigurace**
    - [x] Analyzovat `android/build.gradle.kts`
    - [x] Vynutit Java 17 v `android/build.gradle.kts` pro všechny subprojekty
- [x] **Fáze 2: Verifikace**
    - [x] Spustit `flutter clean`
    - [x] Identifikovat příčinu selhání buildu (konflikt systémových proměnných)
