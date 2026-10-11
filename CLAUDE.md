# AJ Tudor – poznámky pro Claude

Struktura projektu, pravidla a kontrola změn jsou v `README.md`, testy v `test/README.md`.

## Rozbor nahlášené lekce z telefonu

Uživatel napíše třeba „chat z 9. 10. se pokazil, analyzuj ho“. Telefon je spárovaný přes bezdrátové ladění a aplikace běží jako debug build (`run-as` jinak nefunguje).

- adb: `/c/Users/tosma/AppData/Local/Android/Sdk/platform-tools/adb.exe` (není v PATH), balíček `com.tudor.aj_tudor`.
- Data aplikace jsou v `app_flutter/` (`getApplicationDocumentsDirectory`):
  - `db.sqlite`: lekce `sessions`, přepis `transcripts`, chyby `error_logs` a problémy nahlášené v historii `session_issues` (`note`, nepovinně `transcript_id` repliky).
  - `logs/sessions/session_<id>.log`: log jedné lekce od startu hovoru do konce rozboru po lekci. Hlavička obsahuje datum, řádky jen čas. Bez hlučných řádků o audio chuncích. Drží se posledních 30.
  - `logs/latest.log` a `logs/previous.log`: úplný log posledních dvou spuštění aplikace (při každém spuštění se přepíše).

Stažení do scratchpadu (Git Bash):

```bash
ADB=/c/Users/tosma/AppData/Local/Android/Sdk/platform-tools/adb.exe
"$ADB" exec-out run-as com.tudor.aj_tudor cat app_flutter/db.sqlite > db.sqlite
"$ADB" shell run-as com.tudor.aj_tudor ls app_flutter/logs/sessions
"$ADB" exec-out run-as com.tudor.aj_tudor cat app_flutter/logs/sessions/session_7.log > session_7.log
```

Postup:
1. V `db.sqlite` najít lekce daného dne a jejich nahlášené problémy. Časy (`started_at`, `created_at`, `timestamp`) jsou unixové sekundy, převádět na místní čas. Python spouštět s `PYTHONIOENCODING=utf-8`, přepis obsahuje češtinu i nelatinková písmena z chybného STT.
2. Je-li u problému `transcript_id`, čas té repliky (`transcripts.timestamp`) ukazuje místo v logu lekce.
3. V logu sledovat stavy agenta, `[VAD]` (místní detekce řeči, `➡️ activityStart` a `➡️ activityEnd` ohlášené serveru), `inputTranscription` (živý přepis), `✍️ Opravný přepis` (nahrazený text repliky), `turnComplete` a pauzy. Rozbor po lekci je na konci logu.

Rozbor po lekci volá Gemini a při přetížení zkouší další modely, každý pokus až 55 s. Nevyhodnocená lekce hned po konci hovoru tedy ještě nemusí znamenat chybu.
