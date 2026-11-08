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

## Fáze 2: režim Lekce vedle pokecu (v kódu 7. 11., čeká na test promptu a ruční test)

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

Jak je to udělané:

- Záložka „Lekce“ (`LessonTab`) ukáže, které výrazy lekce projde: nejvýš 10 nejdéle čekajících kartiček, které hovor dokáže ověřit (stejný výběr jako ve fázi 1). Bez takových kartiček poběží hovor jako pokec.
- Lekci vede tutor, ne režisér. Dostane do promptu sekci REŽIM LEKCE se seznamem výrazů v pořadí a postupem: situace v angličtině, výraz neříct první, nápověda českou stranou kartičky, pak výraz říct a nechat zopakovat, po správném výrazu pochvala a rovnou další. Pravidla oprav zůstávají. Prompt pokecu se nemění.
- Režisér je během lekce vypnutý, stejně jako změna tématu při opakování tutora a odlehčení po krátkých odpovědích (v lekci jsou krátké odpovědi běžné).
- Splnění výrazu hlídá aplikace stejně jako v pokecu. Po každém splněném výrazu tutor skrytě dostane, co student už řekl a co zbývá. Po posledním výrazu nebo po 15 minutách dostane pokyn lekci uzavřít a hovor pak pokračuje pokecem, zase s režisérem.
- Na obrazovce je během lekce „Lekce: 3/10 výrazů“ s ukazatelem, po hovoru souhrn. Po výpadku spojení dostane nové spojení i průběh lekce.
- Gramatický cíl lekce viz fáze 3, bod 1.

**Lekce podle druhu kartičky (8. 11., po lekci 23).** V lekci 23 tutor po první odpovědi výraz hned prozradil (u „not prepared“ a „take a sick day“) a student správně poznamenal, že větu z kartičky si doslova nepamatuje a dá se říct i jinak. Proto:
- Kartička má druh (`CardKind`): slovíčko, nebo gramatika. Gramatika je útržek opravené věty s pomocným slovesem, záporem nebo zájmenem (didn't relax, not prepared, be created for, had a busy week), nebo s gramatickou poznámkou v češtině („přepsal (minulý čas)“). Ostatní kartičky jsou slovíčka (winterized, take a sick day, unwind). Typ chyby v databázi se na to nehodí („winterized“ je tam gramatika).
- Slovíčko se tutor ptá česky jako kartička („Jak řekneš ‚zazimovat‘? Co děláš s lodí před zimou?“) a uzná i jiný tvar. Podobný výraz pochválí, zmíní výraz z kartičky a jde dál bez drilu. Neznámé slovíčko řekne a nechá zopakovat.
- Gramatiku tutor procvičí situací a uzná jakoukoli správnou větu vlastními slovy.
- Splnění posoudí `LessonCardJudge` (flash-lite, jeden požadavek na repliku v lekci, jen když doslovné porovnání nic nenašlo). Funkce (tools) Live API se nepoužívají, kvůli nim dřív zamrzal zvuk. Test rozhodčího (`tool/prompt_eval/lesson_judge.dart`, 10 replik): 10 z 10.
- Anglické znění gramatické kartičky tutor nedostane, jen českou stranu: v testu ho jinak vkládal do otázek („…but you are not prepared?“) a vyžadoval ho, i když student řekl správnou větu vlastními slovy. Průběh lekce mu aplikace u gramatiky hlásí taky česky.
- Test promptu lekce (`private/lesson_cases_v4.json`, 9 situací po dvou odpovědích): 89 %. Začátek, další kartička, oprava a uzavření prošly. Tutor jednou nechal zopakovat jen „find a workaround“ bez věty a jednou se u gramatické kartičky zeptal „how would you say ‚neudělal to‘“ se dvěma otázkami.
- Test promptu lekce (7. 11., 9 situací po dvou odpovědích, rozhodčí `gemini-3.5-flash-lite`): 72 %. Situace pro další výraz a česká nápověda prošly všechny. Tutor jednou prozradil výraz v otázce („how would you say that you didn't relax“), jednou si spletl dvě podobné kartičky („odpočinout“ a „neodpočinul si“) a jednou začal lekci znovu. Zadání jsem podle toho upravil a případ s vypršením času opravil (studentova věta měla chybu, tak ji tutor správně nejdřív opravil). Ověří se to dalším během.

## Fáze 3: další vylepšení výuky

Body 1, 3, 4 a 5 jsou v kódu od 7. 11. Body 2 a 6 mění prompt pokecu a 8. 11. testem neprošly (viz níže), prompt pokecu zůstává ve verzi ze 7. 11.

1. **Gramatický cíl lekce.** Místo pasivního seznamu deseti starých chyb jedna věc na lekci (u studenta nejčastěji minulý čas, -s ve 3. osobě, předložky at/on/in). Tutor volí témata, ve kterých se přirozeně objeví (minulý čas: víkend, co se stalo v práci). V Lekci povinně, v pokecu nejvýš jako lehký směr.
   *Hotovo jen v Lekci:* cíl je nejčastější gramatický druh chyby (čas, tvar slovesa, předložka, slovosled) z posledních 5 lekcí s rozborem podle druhů. Tutor podle něj volí situace k výrazům, chyby v něm opravuje vždy a při uzavření řekne, jak šel. Záložka Lekce cíl ukáže. V pokecu zatím ne, prompt pokecu se tím nemění.
2. **Nechat studenta opravit se sám.** Nejdřív nápověda („Jak by to bylo v minulosti?“), hotová věta až když na to nepřijde. Prompt to u gramatiky chce, ale tutor skoro vždycky rovnou řekne správnou větu. Zpřísnit a ověřit testem.
3. **Jemnější typy chyb.** Rozbor po lekci dělí chyby jen na gramatiku, slovíčka a výslovnost. Nově čas, -s, předložka, slovosled, slovíčko, české slovo. Obrazovka Pokrok pak ukáže, co se zlepšuje, a podle toho se vybírá cíl lekce (bod 1).
   *Hotovo:* rozbor dává každé chybě `category` (`ErrorCategory`: čas, tvar slovesa, předložka, vazba a slovosled, volba slova, české slovo, výslovnost, ostatní) a ukládá ji do `error_logs.category`. Karta „Co se zlepšuje“ v Pokroku porovná chyby na lekci v posledních 3 lekcích se 3 předtím. Starší lekce druhy neznají, takže srovnání se naplní až s dalšími lekcemi.
4. **Podíl řeči studenta.** Aplikace už počítá slova studenta i tutora. Zobrazit a hlídat, aby student mluvil aspoň polovinu času (v lekci 19 měl tutor dlouhé odpovědi).
   *Hotovo:* rozbor po lekci spočítá slova z uloženého přepisu (`sessions.student_words`, `tutor_words`). Podíl je v detailu lekce a v kartě „Co se zlepšuje“. Když student měl méně než polovinu, rozbor napíše tutorovi do sebekritiky na příště, ať mimo opravy mluví kratčeji. Upozornění během hovoru zatím není, to by znamenalo další pokyn tutorovi a test.
5. **Stálejší odhad úrovně.** Úroveň v profilu skáče mezi A2 a B1 podle jedné lekce a tutor mění styl. Průměr z posledních ~5 lekcí.
   *Hotovo:* každá lekce si uloží odhad rozboru (`sessions.estimated_level`, krátké lekce ne) a profil dostane nejčastější odhad z posledních 5 lekcí, při shodě ten novější. Od 8. 11. se úroveň odhaduje jen z lekcí, kde student řekl aspoň 150 slov (lekce 23 měla 58 slov, hlavně zopakované věty, a úroveň spadla na A2).
   *Profil dovedností (8. 11.):* rozbor navíc ukládá jemnější úroveň (B1−, B1, B1+) s jednou větou proč a počet replik studenta. Karta „Co se zlepšuje“ ukazuje u poslední lekce chyby v gramatice a ve slovní zásobě na 100 slov, slova na repliku a podíl řeči, vedle průměr 4 lekcí předtím (`SkillProfile`). Úroveň pro tutora zůstává hrubá (A1–B2).
6. **Kratší prompt tutora.** Kolem 20 tisíc znaků se zpracovává při každém tahu. Zkrátit opakovaná pravidla a velká písmena (dokumentace Gemini radí vyhýbat se přehnaně důraznému jazyku) a ověřit testem.

**Test bodů 2 a 6 (8. 11.):** prompt zkrácený z 20 787 na 13 232 znaků (bez profilu z 14 645 na 7 437) s nápovědou místo hotové věty u času a tvaru slovesa. Celý test (63 případů po dvou odpovědích, rozhodčí `gemini-3.5-flash-lite`): rozhodčí 91 % → 76 %, oprava chyby 88 → 50 %, česká věta 91 → 73 %, pokračování po opravě 63 → 38 %, odpověď na dotaz 67 → 40 %. Lepší jen čekání, držení tématu a povzbuzení. Proto se nenasadil.
- Nápovědu Live model nedodržuje: většinou dál řekne hotovou větu, a když napoví, tak občas anglicky nebo bez „Zkus to!“. Bod 2 zatím odkládám.
- Zkrácením se ztratily drobnosti, které podrobné znění drželo: české slovo „dosadit do své věty“, otázka k tématu po zopakování, pořadí čas před předložkou u druhé chyby. Prompt pokecu Live modelu evidentně pomáhá i svou důrazností.
- Zkrácená verze je v `tool/prompt_eval/private/kratsi_system_prompt_builder.dart.txt`, výsledky v `results/kratsi`.
- Další pokus: jen malé, cílené změny ověřeného promptu, každá zvlášť ověřená. Kandidáti: popis jen té úrovně, kterou student má (asi 600 znaků méně), rada režiséra se zahodí, když se hovor posunul jinam (lekce 22), mírnější příklad na jednoslovnou odpověď místo „Come on, tell me more! Why?“ (dvě otázky naráz) a fakta z profilu bez „navaž na ně (How is your dog doing?)“.

## Technické body z rozborů lekcí

- **Ztracená replika po výpadku sítě** (lekce 19, 20:40): po obnovení spojení tutor mlčel, dokud student neřekl „Haló“, protože z repliky nebyl přepis. Šlo by po obnovení poslat znovu zvuk nezodpovězené repliky.
- **Limit Live modelu 65 tisíc tokenů za minutu:** v delší lekci se k němu spotřeba blíží (týdenní maximum 63,7 tisíce). Sledovat. Aplikace dnes obnovuje spojení při 25 tisících tokenech kontextu, případně to udělat dřív.
- **Výslovnost slov:** `gemini-3.8-flash-tts` má jen 10 požadavků denně, pak aplikace přejde na Lite TTS. Uložené nahrávky se používají znovu, takže limit se týká jen nových slov.

## Jak ověřovat

Každá změna promptu tutora nebo režiséra se před nasazením porovná testem `tool/prompt_eval/`: stejné případy se starým a novým promptem, stejný rozhodčí. Limity bezplatné úrovně a rozpočet testů jsou v [`tool/prompt_eval/README.md`](../tool/prompt_eval/README.md). Před každým během se nejdřív pustí `--dry-run` a odhad spotřeby.
