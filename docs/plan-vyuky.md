# Plán vylepšení výuky (stav k 7. 11. 2026)

## Princip

Angličtinu i metodiku výuky model zná sám, učebnice do promptu nepatří. U Live modelu se celý kontext hovoru zpracovává při každém tahu znovu (v lekci 19 rostla spotřeba 12 782 → 13 533 → 13 707 tokenů na repliku). Samotný prompt tutora má kolem 6 400 tokenů a bezplatná úroveň dovoluje 65 tisíc tokenů za minutu. Učebnice by hovor zdražila i zpomalila.

Model ale neví nic o studentovi: co mu jde, co pořád opakuje a co si už procvičil. Tam je největší prostor. Všechno níže stojí na datech, která aplikace už má (kartičky s plánem opakování, chyby z rozborů, přepisy lekcí).

## Hotovo (4.–6. 11.)

- **Prompt tutora:** jasné vymezení skutečné chyby a drobnosti (opravují se i předložky at/on/in, neopravuje se člen a množné číslo), pořadí důležitosti chyb, povinný návrat k druhé chybě po zopakování, fakta z profilu nejsou zdroj nových témat, pravidla opravování mají přednost před pamětí z minulé lekce.
- **Režisér:** mlčí po opravě a při loučení, neřeší gramatiku, netlačí hovor k jídlu a koníčkům z profilu, zastaralá rada se zahodí.
- **Fakta o studentovi** zapisuje jen rozbor po lekci a jen trvalá. Profil pročištěn ze 40 na 16 faktů.
- **Modely podle limitů bezplatné úrovně:** častá volání na flash-lite (500 denně), 3.8 Flash (20 denně) jen pro rozbor po lekci a témata, vyčerpaný denní limit se vynechá do 9:00.
- **Test promptu** na skutečných replikách z lekcí: [`tool/prompt_eval/`](../tool/prompt_eval/README.md).

## Fáze 0: vyhodnotit úpravy promptu (hotovo 7. 11.)

Rozhodčí (`gemini-3.5-flash-lite`) ohodnotil starý a nový prompt tutora na 63 případech po dvou odpovědích: celkem 81 % → 91 %. Oprava chyby 58 → 88 %, návrat k druhé chybě 54 → 69 %, pokračování po opravě 38 → 63 %, držet se tématu 75 → 81 %. Horší je jen „nechat domluvit“ (75 → 63 %), protože jedna věcně správná odpověď měla víc než 8 slov. Odbočení k jídlu (93 % v obou verzích) způsoboval hlavně starý profil v testovacích případech: se současným profilem neodbočila ani jedna z 22 odpovědí (dřív 4).

## Fáze 1: kartičky v pokecu (v kódu 7. 11., čeká na test režiséra a ruční test)

Hovor kartičky plní i opakuje. Jak je to udělané:

- `ConversationCards` (`lib/services/flashcards/conversation_cards.dart`) načte na začátku hovoru dnešní kartičky. Vynechá výslovnost, cíle delší než 4 slova a jednoslovné cíle kratší než 6 písmen („go“, „has“, „least“ student řekne náhodou). Z kopie databáze ze 4. 11. jde v hovoru ověřit 55 kartiček z 66.
- Režisér dostane nejvýš 15 nejdéle čekajících kartiček a vrátí `flashcardId` té, kterou vpletl. Tutor dostane k radě pokyn, ať výraz neřekne první. Nápověda na displeji, která výraz prozrazuje, se nezobrazí. Vpletená kartička se v hovoru znovu nenabídne a další přijde nejdřív za 2 minuty.
- Test režiséra (7. 11., `gemini-3.5-flash-lite`, 70 chvil z lekcí): s kartičkami není horší (rozhodčí 85 → 88 %, po opravě mlčí 68 → 84 %, gramatika 94 = 94 %, jídlo 84 → 83 %). Kartičku vplete zřídka (5 ze 70 chvil) a ve 2 z 5 případů napíše výraz přímo do rady, i s příkladem v zadání. Proto výraz v radě kartičku nezahodí, pojistkou je pokyn tutorovi a kontrola zopakování. Výraz „unwind“ (odpočinout si) táhne hovor k odpočinku a koníčkům.
- Výraz se porovnává s opravným přepisem repliky bez ohledu na velká písmena, interpunkci a zkratky (don't = do not). „be“ smí být v jakémkoli tvaru, „one's“ znamená my/your/his…, poznámka v závorce se ignoruje. Výraz, který tutor řekl v posledních 4 replikách, kartičku nesplní.
- Splněná kartička dostane „Dobré“, na displeji se ukáže „Kartička splněna v hovoru“ a po konci hovoru souhrn.
- Rozbor po lekci zařadí výrazy, na které se student zeptal, mezi chyby typu „vocabulary“ a dá je na začátek. Kartičky vzniknou nejvýš z prvních 6 a jen s cílem do 4 slov. Ostatní chyby jdou do logu chyb.

- Ruční test 7. 11. (lekce 22, 15 minut o práci): v hovoru se splnily 3 kartičky (work on, need to fix, plan to refactor) a posunuly se na 9. a 11. 11. Režisér jednou vpletl „find a workaround“, rada výraz neobsahovala a tutor ho neřekl. Rozbor po lekci přidal 4 kartičky, mezi nimi „propojení → connection“ z otázky „jak se řekne“. Rozbor ale běžel na flash-lite (3.8 Flash byl přetížený, 3.6 Flash vyčerpaný opravným přepisem) a jedna kartička je špatně („trávit týdně na → spend a week on“).

Původní zadání:

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
