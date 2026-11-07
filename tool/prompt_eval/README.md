# Test promptu hlasového tutora

Ověřuje systémový prompt tutora na skutečných replikách z lekcí. Každý případ pošle živému modelu (`gemini-3.8-live`) historii lekce až do jedné repliky studenta a vyhodnotí odpověď tutora:

- automatickými kontrolami (`checks.dart`): nejvýš jedna otázka, oprava končí výzvou k zopakování, odpověď neodbočí k jídlu a koníčkům, neopakuje dřívější otázku atd.,
- rozhodčím modelem (`gemini-3.8-flash`) podle očekávaného chování, které je u každého případu popsané.

Prompt se sestaví stejně jako v aplikaci (`SystemPromptBuilder.buildTutorPrompt`), takže test měří přesně to, co je v kódu. Text místo zvuku: přepis řeči, detekci konce řeči ani ticho test neověří.

## Spuštění

Potřebuje proměnnou prostředí `GEMINI_API_KEY`. Ve Windows ji z uživatelských proměnných načte PowerShell:

```powershell
$env:GEMINI_API_KEY = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User')
dart run tool/prompt_eval/run.dart --label baseline --runs 3
```

- `--only 19-668,2-40` spustí jen vybrané případy,
- `--no-judge` vynechá rozhodčí model,
- `--cases tool/prompt_eval/private/cases_novy_profil.json` načte případy z jiného souboru (např. se současným profilem studenta),
- `director.dart --cases tool/prompt_eval/private/director_cases_karticky.json` pustí test režiséra s dnešními kartičkami: soubor má navíc pole `dueCards` (kartičky na opakování od nejstarší) a režisér z nich dostane zásobu stejně jako v aplikaci. Kontroly hlídají, že vplete jen nabídnutou kartičku, po opravě a při loučení žádnou a že nápověda na displeji výraz neprozradí; rozhodčí posoudí, jestli kartička k hovoru sedí,
- `--compare baseline candidate` porovná dva uložené běhy podle druhu případu i po jednotlivých případech.

Celý běh (63 případů × 3) trvá zhruba 30–45 minut. Před změnou promptu se uloží výchozí běh, po změně se pustí znovu pod jiným názvem a oba se porovnají. Změna má smysl, jen když není horší v žádném druhu případů.

## Případy a výsledky

Případy (`private/cases.json`) i výsledky (`private/results/`) obsahují repliky z lekcí, proto je git ignoruje. Případy vznikly z databáze aplikace (`db.sqlite` z telefonu, viz `CLAUDE.md`). Každý obsahuje historii lekce, repliku studenta, druh situace a popis očekávaného chování.

Druhy případů: `correct` (oprava chyby), `no_correction` (drobnost nebo správně), `translate` (česká věta, „jak se řekne“), `wait` (váhání), `continue` (po zopakování), `second_error` (návrat k druhé chybě z téže promluvy), `stay_on_topic` (neodbočit k jídlu a koníčkům), `encourage`, `clarify`, `answer`.
