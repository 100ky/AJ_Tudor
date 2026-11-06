# Plán vylepšení výuky (stav k 6. 11. 2026)

## Princip

Angličtinu i metodiku výuky model zná sám, učebnice do promptu nepatří. U Live modelu se celý kontext hovoru zpracovává při každém tahu znovu (v lekci 19 rostla spotřeba 12 782 → 13 533 → 13 707 tokenů na repliku). Samotný prompt tutora má kolem 6 400 tokenů a bezplatná úroveň dovoluje 65 tisíc tokenů za minutu. Učebnice by hovor zdražila i zpomalila.

Model ale neví nic o studentovi: co mu jde, co pořád opakuje a co si už procvičil. Tam je největší prostor. Všechno níže stojí na datech, která aplikace už má (kartičky s plánem opakování, chyby z rozborů, přepisy lekcí).

## Hotovo (4.–6. 11.)

- **Prompt tutora:** jasné vymezení skutečné chyby a drobnosti (opravují se i předložky at/on/in, neopravuje se člen a množné číslo), pořadí důležitosti chyb, povinný návrat k druhé chybě po zopakování, fakta z profilu nejsou zdroj nových témat, pravidla opravování mají přednost před pamětí z minulé lekce.
- **Režisér:** mlčí po opravě a při loučení, neřeší gramatiku, netlačí hovor k jídlu a koníčkům z profilu, zastaralá rada se zahodí.
- **Fakta o studentovi** zapisuje jen rozbor po lekci a jen trvalá. Profil pročištěn ze 40 na 16 faktů.
- **Modely podle limitů bezplatné úrovně:** častá volání na flash-lite (500 denně), 3.8 Flash (20 denně) jen pro rozbor po lekci a témata, vyčerpaný denní limit se vynechá do 9:00.
- **Test promptu** na skutečných replikách z lekcí: [`tool/prompt_eval/`](../tool/prompt_eval/README.md).

## Fáze 0: vyhodnotit úpravy promptu (7. 11.)

Rozhodčí ohodnotí odpovědi starého a nového promptu tutora i režiséra. Nasadí se jen to, co není horší v žádné kategorii případů.

## Fáze 1: kartičky v pokecu

Hovor kartičky plní i opakuje.

- **Zásoba pro režiséra:** na začátku hovoru dostane až 15 kartiček, které jdou dnes na opakování. Vybírá si z nich ty, které sedí k aktuálnímu tématu, a tutorovi našeptá situaci, ve které je student přirozeně použije. Kartičku, která k tématu nesedí, netlačí. Přirozený hovor má přednost, realisticky jedna kartička za 2–3 minuty.
- **Splnění kartičky:** student výraz řekne sám a správně. Aplikace porovná opravný přepis repliky s cílovým výrazem a ověří, že ho tutor v předchozích tazích sám neřekl, protože zopakování po tutorovi („Zkus to říct: …“) se nepočítá. Splněná kartička dostane hodnocení „Dobré“ (interval ×2) a dnes už v kartičkách nebude. Kontrola nepotřebuje další volání modelu.
- **Špatné použití kartičku nepenalizuje:** tutor opraví jako obvykle a kartička zůstane na dnešek. Hovor ji jen může splnit.
- **Kartičky z „jak se řekne“:** výrazy, na které se student v hovoru zeptal česky („mashed potatoes“, „winterize the boat“, „dried apple slices“), se stanou kartičkami. Dnes končí jen v seznamu slovíček v profilu. Strop kolem 6 nových kartiček na lekci včetně kartiček z chyb.
- **Po lekci** se ukáže „N kartiček splněno v hovoru“.
- **Ověření:** nové případy v testu promptu. Režisér má kartičku vplést přirozeně, nesmí vzniknout výslech a po opravě dál mlčí.

## Fáze 2: režim Lekce vedle pokecu

AJ Tudor zůstává hlavně kamarád na pokec. Lekce je samostatný režim, který si student vybere. Každý má vlastní zadání, takže se pravidla neperou.

| | Pokec (výchozí) | Lekce |
|---|---|---|
| Cíl | povídat si | projít dnešní kartičky a jeden gramatický cíl |
| Kartičky | režisér je vplete, jen když se hodí | režisér je zařazuje cíleně jednu po druhé |
| Konec | když chce student | po projití kartiček, nejpozději po ~15 minutách |
| Opravy | stejné | stejné |

- Lekce bude další záložka v nastavení hovoru vedle „Historie“, „Scénáře“ a „Volný“.
- Na obrazovce průběh, např. „6/10 kartiček“.
- Na konci tutor lekci uzavře (co šlo, co příště) a nabídne pokračovat pokecem.
- Kartičky splněné v pokecu i v lekci zapisují do stejného plánu opakování.

## Fáze 3: další vylepšení výuky

1. **Gramatický cíl lekce.** Místo pasivního seznamu deseti starých chyb jedna věc na lekci (u studenta nejčastěji minulý čas, -s ve 3. osobě, předložky at/on/in). Tutor volí témata, ve kterých se přirozeně objeví (minulý čas: víkend, co se stalo v práci). V Lekci povinně, v pokecu nejvýš jako lehký směr.
2. **Nechat studenta opravit se sám.** Nejdřív nápověda („Jak by to bylo v minulosti?“), hotová věta až když na to nepřijde. Prompt to u gramatiky chce, ale tutor skoro vždycky rovnou řekne správnou větu. Zpřísnit a ověřit testem.
3. **Jemnější typy chyb.** Rozbor po lekci dělí chyby jen na gramatiku, slovíčka a výslovnost. Nově čas, -s, předložka, slovosled, slovíčko, české slovo. Obrazovka Pokrok pak ukáže, co se zlepšuje, a podle toho se vybírá cíl lekce (bod 1).
4. **Podíl řeči studenta.** Aplikace už počítá slova studenta i tutora. Zobrazit a hlídat, aby student mluvil aspoň polovinu času (v lekci 19 měl tutor dlouhé odpovědi).
5. **Stálejší odhad úrovně.** Úroveň v profilu skáče mezi A2 a B1 podle jedné lekce a tutor mění styl. Průměr z posledních ~5 lekcí.
6. **Kratší prompt tutora.** Kolem 20 tisíc znaků se zpracovává při každém tahu. Zkrátit opakovaná pravidla a velká písmena (dokumentace Gemini radí vyhýbat se přehnaně důraznému jazyku) a ověřit testem.

## Technické body z rozborů lekcí

- **Ztracená replika po výpadku sítě** (lekce 19, 20:40): po obnovení spojení tutor mlčel, dokud student neřekl „Haló“, protože z repliky nebyl přepis. Šlo by po obnovení poslat znovu zvuk nezodpovězené repliky.
- **Limit Live modelu 65 tisíc tokenů za minutu:** v delší lekci se k němu spotřeba blíží (týdenní maximum 63,7 tisíce). Sledovat. Aplikace dnes obnovuje spojení při 25 tisících tokenech kontextu, případně to udělat dřív.
- **Výslovnost slov:** `gemini-3.8-flash-tts` má jen 10 požadavků denně, pak aplikace přejde na Lite TTS. Uložené nahrávky se používají znovu, takže limit se týká jen nových slov.

## Jak ověřovat

Každá změna promptu tutora nebo režiséra se před nasazením porovná testem `tool/prompt_eval/`: stejné případy se starým a novým promptem, stejný rozhodčí. Limity bezplatné úrovně a rozpočet testů jsou v [`tool/prompt_eval/README.md`](../tool/prompt_eval/README.md). Před každým během se nejdřív pustí `--dry-run` a odhad spotřeby.
