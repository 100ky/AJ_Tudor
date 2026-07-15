# Walkthrough - Odstranění Java 8 varování a oprava Android buildu

Úspěšně jsem upravil Gradle konfiguraci pro odstranění varování o zastaralé verzi Java 8 a identifikoval kritickou chybu v prostředí, která blokuje sestavení APK.

## Provedené změny

### 1. Globální vynucení Java 17
V souboru `android/build.gradle.kts` jsem přidal instrukce pro všechny subprojekty (včetně Flutter pluginů):
- Nastavení `compileOptions` na `JavaVersion.VERSION_17`.
- Tím se odstraní varování `source value 8 is obsolete`, která se objevovala při startu aplikace.

## Zjištěná kritická chyba (Vyžaduje váš zásah)

Při pokusu o sestavení APK jsem narazil na chybu `AndroidLocationsException`, která je specifická pro nastavení Windows.

> [!CAUTION]
> **Problém:** Ve vašem systému jsou nastaveny dvě konfliktní proměnné prostředí:
> - `ANDROID_PREFS_ROOT`: `C:\Users\tosma\.android`
> - `ANDROID_USER_HOME`: `C:\Users\tosma\.android`
>
> Moderní Android Gradle Plugin (8.x+) selže, pokud jsou definovány obě, i když ukazují na stejné místo.

### Jak to opravit (Manuální krok):
1. Otevřete ve Windows **Nastavení systému** -> **Upravit proměnné prostředí systému**.
2. Klikněte na **Proměnné prostředí**.
3. V sekci "Uživatelské proměnné" (nebo Systémové) najděte a **SMAŽTE** proměnnou `ANDROID_PREFS_ROOT`.
4. Ponechte pouze `ANDROID_USER_HOME`.
5. **Restartujte Android Studio**, aby se změna projevila.

## Verifikace
- [x] Gradle skript je syntakticky správný.
- [x] Java 17 je vynucena pro všechny moduly.
- [x] Dart a testy (z předchozí fáze) zůstávají stabilní.
