/// Oblast konverzačních témat: evidence témat počítá, kdy se o ní naposledy mluvilo.
class TopicArea {
  /// Stálý klíč (ukládá se do databáze a vrací ho rozbor lekce).
  final String id;

  /// Český název pro prompty.
  final String label;

  /// Co do oblasti patří, aby rozbor zařadil témata stejně.
  final String description;

  /// Konkrétní náměty, ze kterých může příprava tématu brát, když je oblast nová.
  final List<String> seeds;

  const TopicArea(this.id, this.label, this.description, this.seeds);
}

/// Katalog oblastí témat pro dospělého studenta. Plánovač z něj nabízí oblasti, o kterých
/// se dlouho nemluvilo nebo vůbec ne: dřív generátory braly témata jen z profilu a ze
/// souhrnů lekcí, a tak se hovory točily kolem práce a IT (v 22 z 34 lekcí je otevřel tutor).
abstract final class TopicCatalog {
  static const List<TopicArea> areas = [
    TopicArea('prace', 'Práce a kariéra', 'pracovní den, kolegové, šéf, porady, kariérní plány', [
      'ideální pracovní den',
      'práce z domova, nebo v kanceláři',
      'čím jsi chtěl být jako dítě',
      'nejlepší rada, kterou jsi v práci dostal',
      'dovednost, kterou by ses rád naučil',
      'jak vypadá tvoje pracovní ráno',
    ]),
    TopicArea('technologie', 'Technologie a internet',
        'programování, aplikace, mobily, umělá inteligence, sociální sítě, život online', [
      'aplikace, bez které bys nevydržel',
      'týden bez mobilu',
      'umělá inteligence v běžném životě',
      'chytrá domácnost',
      'sociální sítě: pomáhají, nebo škodí?',
      'technologie, která tě zklamala',
    ]),
    TopicArea('jidlo', 'Jídlo a vaření', 'oblíbená jídla, vaření, grilování, restaurace, kuchyně jiných zemí', [
      'jídlo z dětství',
      'nejlepší restaurace, kde jsi byl',
      'kuchyně, kterou bys chtěl ochutnat',
      'snídaně: sladká, nebo slaná?',
      'jídlo, které nesnášíš',
      'vaření pro návštěvu',
    ]),
    TopicArea('cestovani', 'Cestování a dovolená', 'výlety, země, hotely, plány na cesty, zážitky z dovolené', [
      'vysněná destinace',
      'nejhorší zážitek z dovolené',
      'vlak, auto, nebo letadlo',
      'hotel, nebo kemp',
      'místo v Česku, které by měl vidět každý',
      'co si vždycky zapomeneš sbalit',
    ]),
    TopicArea('priroda', 'Příroda, počasí a roční období', 'turistika, hory, les, voda, počasí, roční období', [
      'oblíbené roční období',
      'hory, nebo moře',
      'nejhezčí výlet do přírody',
      'počasí a nálada',
      'noc pod širákem',
      'zvířata, která jsi potkal v přírodě',
    ]),
    TopicArea('sport', 'Sport a pohyb', 'sporty, cvičení, fandění, pohyb během týdne', [
      'sport, který bys chtěl zkusit',
      'fandíš nějakému týmu?',
      'cvičení doma, nebo v posilovně',
      'olympijské hry',
      'nejhorší sportovní zážitek',
      'pohyb během pracovního týdne',
    ]),
    TopicArea('filmy', 'Filmy, seriály a knihy', 'filmy, seriály, anime, knihy, postavy a příběhy', [
      'film, který tě dojal',
      'kniha, kterou bys doporučil',
      'kino, nebo doma',
      'postava, kterou bys chtěl být',
      'filmové klišé, které tě štve',
      'seriál na dlouhý víkend',
    ]),
    TopicArea('hudba', 'Hudba a umění', 'hudba, koncerty, nástroje, výstavy, umělci', [
      'písnička, která ti zvedne náladu',
      'první koncert',
      'hudba při práci',
      'umělec, kterého obdivuješ',
      'muzeum, nebo galerie',
      'kdybys uměl hrát na nějaký nástroj',
    ]),
    TopicArea('zvirata', 'Zvířata a mazlíčci', 'domácí mazlíčci, péče o zvířata, zoo, divoká zvířata', [
      'pes, nebo kočka',
      'zvíře, které by sis nikdy nepořídil',
      'zoo: ano, nebo ne',
      'vtipná historka s mazlíčkem',
      'kdyby zvířata mluvila',
      'kdo se postará o mazlíčka na dovolené',
    ]),
    TopicArea('zdravi', 'Zdraví a životní styl', 'zdraví, nemoc, spánek, stres, zvyky, odpočinek', [
      'jak se zbavuješ stresu',
      'spánek a ranní vstávání',
      'zlozvyk, kterého by ses rád zbavil',
      'návštěva u lékaře',
      'zdravé jídlo, nebo chutné jídlo',
      'jak vypadá tvůj ideální odpočinek',
    ]),
    TopicArea('domov', 'Domov, bydlení a zahrada', 'byt, dům, nájem, sousedé, domácí práce, opravy, zahrada', [
      'byt, nebo dům',
      'oblíbené místo doma',
      'sousedé',
      'domácí práce, které nesnášíš',
      'stěhování',
      'opravy a kutilství doma',
    ]),
    TopicArea('rodina', 'Rodina a přátelé', 'rodina, partner, kamarádi, vztahy, společný čas', [
      'nejlepší kamarád',
      'rodinné tradice',
      'jak se seznamuješ s novými lidmi',
      'sourozenci',
      'rada od rodičů, kterou si pamatuješ',
      'víkend s přáteli',
    ]),
    TopicArea('penize', 'Peníze a nakupování', 'nákupy, ceny, šetření, reklamace, výdaje', [
      'nejlepší nákup za poslední rok',
      'nakupovat online, nebo v obchodě',
      'jak šetříš peníze',
      'co bys udělal s výhrou v loterii',
      'zbytečná věc, kterou jsi koupil',
      'reklamace a vracení zboží',
    ]),
    TopicArea('doprava', 'Auta a doprava', 'auta, opravy aut, MHD, kolo, dopravní zácpy, cestování po městě', [
      'první auto',
      'MHD ve městě',
      'elektromobily',
      'nejdelší cesta autem',
      'kolo ve městě',
      'jak přežít dopravní zácpu',
    ]),
    TopicArea('svatky', 'Svátky, oslavy a tradice', 'Vánoce, narozeniny, svatby, Silvestr, zvyky, dárky', [
      'Vánoce u vás doma',
      'nejlepší oslava narozenin',
      'tradice z jiných zemí',
      'svatby',
      'Silvestr doma, nebo venku',
      'dárek, který tě nejvíc potěšil',
    ]),
    TopicArea('sluzby', 'Každodenní situace a služby', 'úřady, pošta, kadeřník, restaurace, řemeslníci, reklamace', [
      'na poště a na úřadě',
      'u kadeřníka',
      'objednávka v restauraci',
      'ztracená věc',
      'zavolat řemeslníka',
      'stížnost na službu',
    ]),
    TopicArea('uceni', 'Učení a vzdělávání', 'kurzy, učení jazyků, sebevzdělávání, workshopy, dovednosti, vzpomínky na učitele', [
      'jak se učíš jazyky',
      'online kurz, nebo učitel naživo',
      'učitel, na kterého vzpomínáš',
      'kurz, který tě bavil',
      'dovednost, kterou se chceš naučit',
      'naučit se něco nového v dospělosti',
    ]),
    TopicArea('spolecnost', 'Společnost a zprávy', 'zprávy, město a vesnice, ekologie, dobrovolnictví, generace', [
      'život ve městě, nebo na vesnici',
      'ekologie v běžném životě',
      'dobrovolnictví',
      'zpráva, která tě v poslední době zaujala',
      'co bys změnil ve svém městě',
      'tvoje generace a generace rodičů',
    ]),
    TopicArea('veda', 'Věda, vesmír a budoucnost', 'vesmír, vynálezy, budoucnost, záhady, roboti', [
      'život na Marsu',
      'svět za 50 let',
      'vynález, který změnil svět',
      'cestování v čase',
      'roboti v domácnosti',
      'záhady, které věda ještě nevyřešila',
    ]),
    TopicArea('dilemata', 'Dilemata a hypotetické otázky', 'co bys dělal kdyby, would you rather, myšlenkové experimenty', [
      'superschopnost na jeden den',
      'život bez internetu, nebo bez auta',
      'pustý ostrov a tři věci',
      'večeře s kýmkoli z historie',
      'víc peněz, nebo víc volného času',
      'jedno rozhodnutí, které bys změnil',
    ]),
    TopicArea('vzpominky', 'Vzpomínky a zážitky', 'dětství, první zážitky, trapné situace, nejlepší dny', [
      'nejhezčí vzpomínka z dětství',
      'první brigáda',
      'trapná situace, na kterou nezapomeneš',
      'nejlepší den za poslední rok',
      'místo, kam se rád vracíš',
      'den, kdy se všechno pokazilo, ale dopadlo dobře',
    ]),
    TopicArea('konicky', 'Koníčky a volný čas', 'koníčky, hry, sbírky, tvoření, víkendy, plachtění a další záliby', [
      'koníček, který bys chtěl zkusit',
      'deskové a počítačové hry',
      'sbírání věcí',
      'tvoření rukama',
      'ideální víkend',
      'koníček, kterého ses vzdal',
    ]),
  ];

  static final Map<String, TopicArea> _byId = {for (final area in areas) area.id: area};

  /// Oblast podle klíče; null pro neznámý klíč (např. ze starší verze katalogu).
  static TopicArea? byId(String id) => _byId[id];

  /// Klíče všech oblastí (enum ve schématu odpovědi rozboru).
  static List<String> get ids => [for (final area in areas) area.id];

  /// Seznam oblastí pro prompt rozboru: „klíč: název (co do ní patří)“.
  static String promptList() => areas.map((a) => '- ${a.id}: ${a.label} (${a.description})').join('\n');
}
