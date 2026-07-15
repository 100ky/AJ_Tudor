# Odstranění Gradle varování (Java 8 Obsolete)

Při sestavování aplikace se objevují varování, že Java 8 (source/target value 8) je zastaralá a bude v budoucích verzích odstraněna. Jelikož projekt používá moderní Gradle 9 a AGP 8+, je žádoucí přejít plně na Java 17.

## Současný stav
- `app/build.gradle.kts` už má nastaveno Java 17.
- Varování pravděpodobně pocházejí z Flutter pluginů, které jsou do projektu zahrnuty jako subprojekty a defaultně mohou stále cílit na Java 8.

## Navrhované změny

### 1. Root Gradle Konfigurace

Vynucení Java 17 pro všechny subprojekty (včetně pluginů) v kořenovém souboru.

- **[MODIFY] [build.gradle.kts](file:///C:/Users/tosma/OneDrive/Desktop/AJ_Tudor/android/build.gradle.kts):**
    - Přidání `compileOptions` s `JavaVersion.VERSION_17` do bloku `subprojects`.
    - Zajištění, že i Kotlin v subprojektech cílí na JVM 17.

### 2. Čištění buildu
- Provedení `flutter clean` pro zajištění, že se změny projeví v celém build cache.

## Ověření
- Spuštění `flutter build apk` nebo `flutter run` a kontrola konzole na přítomnost "obsolete" varování.
