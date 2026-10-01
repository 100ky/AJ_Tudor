import 'dart:convert';

/// Krátké jednoúčelové prompty pro dávková volání Gemini (překlady, kartičky,
/// výslovnost, TTS, dril). Dlouhé systémové prompty agentů jsou v `SystemPromptBuilder`.
abstract final class TaskPrompts {
  // ── Překlady a kartičky ─────────────────────────────────────────────────

  /// Překlad anglické věty/fráze do přirozené češtiny (zadání na líc kartičky).
  static String translateToCzech(String english) =>
      'Přelož tuto anglickou větu/frázi do přirozené češtiny (vrať VÝHRADNĚ čistý český překlad bez uvozovek a bez vysvětlování): "$english"';

  /// Vydestiluje z dlouhé opravené věty cílové slovíčko/kolokaci a její překlad.
  /// Odpověď: JSON `{"target": ..., "czech": ...}`.
  static String extractTargetPhrase({
    required String correctForm,
    required String userSaid,
    required String explanation,
  }) =>
      '''Z této opravené anglické věty z konverzace a chyby studenta extrahuj VÝHRADNĚ cílové anglické slovíčko, frázové sloveso nebo ustálenou kolokaci (1–3 slova), kterou se má student naučit, a její přirozený český překlad.
Opravená věta: "$correctForm"
Výrok studenta: "$userSaid"
Vysvětlení chyby: "$explanation"

Vrať VÝHRADNĚ validní JSON bez markdownu a formátování:
{"target": "clear one's head", "czech": "vyčistit si hlavu"}''';

  /// Dávkový překlad zadání kartiček. [cards] jsou objekty `{"id": ..., "english": ...}`.
  /// Odpověď: JSON pole `[{"id": ..., "czechPrompt": ...}]`.
  static String batchTranslateCardsToCzech(List<Map<String, Object?>> cards) =>
      '''Přelož následující anglické věty/fráze do přirozené češtiny pro zadání na výukové kartičky.
Vrať VÝHRADNĚ validní JSON pole objektů bez formátování a bez dalšího textu:
[
  {"id": 1, "czechPrompt": "Přirozený český překlad"}
]

Věty k překladu:
${jsonEncode(cards)}''';

  /// Vygenerování nových slovíček na míru úrovni a zájmům studenta.
  /// Odpověď: JSON pole `[{"czech": ..., "english": ..., "exampleSentence": ...}]`.
  static String randomVocabulary({
    required int count,
    required String level,
    required List<String> interests,
    required Iterable<String> existingWords,
  }) =>
      '''Jsi expert na výuku angličtiny. Vygeneruj přesně $count náhodných, užitečných a moderních anglických slovíček nebo hovorových frází/idiomů pro studenta na úrovni $level.
${interests.isNotEmpty ? 'Témata a zájmy studenta (zaměř se na ně): ${interests.join(', ')}.' : ''}
${existingWords.isNotEmpty ? 'Vyhni se těmto již známým slovíčkům: ${existingWords.take(40).join(', ')}.' : ''}

Každé slovíčko musí mít:
1. "czech": České slovo nebo fráze v základním tvaru (zadání k překladu). Např. "těšit se na", "vytrvalost", "vzdát se".
2. "english": Správný anglický ekvivalent. Např. "look forward to", "perseverance", "give up".
3. "exampleSentence": Příkladová anglická věta s českým překladem a vysvětlením. Např. "I look forward to seeing you. (Těším se, až tě uvidím - vazba se slovesem v -ing)."

Vrať VÝHRADNĚ validní JSON pole objektů bez formátování:
[
  {
    "czech": "těšit se na",
    "english": "look forward to",
    "exampleSentence": "I look forward to seeing you. (Těším se, až tě uvidím.)"
  }
]''';

  // ── Bleskový překlad slova v chatu ──────────────────────────────────────

  /// Systémová instrukce bleskového překladače slov.
  static const String wordTranslationSystem =
      'Jsi bleskový překladač z angličtiny do přirozené češtiny. '
      'Přelož zadané anglické slovo nebo frázi přesně tak, jak odpovídá kontextu věty. '
      'Vrať VÝHRADNĚ čistý český překlad bez uvozovek, bez tečky a bez jakéhokoliv vysvětlování.';

  /// Dotaz na překlad slova [word], volitelně v kontextu věty [contextSentence].
  static String wordTranslationRequest({
    required String word,
    String? contextSentence,
  }) =>
      (contextSentence != null && contextSentence.trim().isNotEmpty)
          ? 'Kontext věty: "${contextSentence.trim()}"\nPřelož výraz: "$word"'
          : 'Přelož výraz: "$word"';

  // ── Výslovnost a TTS ────────────────────────────────────────────────────

  /// Kontext kartičky pro hodnocení mluvené odpovědi studenta.
  static String spokenAnswerHint({
    required String promptContext,
    required String expectedEnglish,
  }) =>
      'Student odpovídá na kartičku se zadáním: "$promptContext". Cílová správná odpověď: "$expectedEnglish".';

  /// Systémová instrukce pro fonetické vyhodnocení nahrávky (odpověď v JSON).
  static String pronunciationSystem({
    required String referenceText,
    String? instructionHint,
  }) =>
      '''Jsi expert na fonetiku a výslovnost moderního anglického jazyka.
Tvým úkolem je detailně analyzovat mluvenou nahrávku studenta a porovnat ji se vzorovým anglickým textem.
${instructionHint ?? ''}
Vzorový anglický text: "$referenceText"

Vyhodnoť:
1. "transcribedText": Přesný přepis toho, co student v angličtině skutečně vyslovil.
2. "overallScore": Celkové skóre výslovnosti a srozumitelnosti od 0.0 do 1.0 (např. 0.92 pro 92 %).
3. "words": Seznam všech rozpoznaných slov s detailním hodnocením:
   - "expectedWord": odpovídající vzorové slovo
   - "recognizedWord": slovo jak ho student vyslovil
   - "isAccurate": true pokud bylo slovo vysloveno foneticky správně a srozumitelně; false pokud byla výslovnost nepřesná, zkomolená nebo chyběla správná hláska.
   - "confidence": číslo 0.0 až 1.0
   - "phoneticTip": krátký český tip pro zlepšení tohoto konkrétního slova (např. "Pozor na znělé /ð/", "Otevřené /æ/").
4. "feedback": Stručné, vstřícné české shrnutí výslovnosti (max 2 věty).

Vrať VÝHRADNĚ validní JSON bez jakéhokoliv markdown formátování dle schématu:
{
  "transcribedText": "I am twenty five years old",
  "overallScore": 0.92,
  "feedback": "Velmi pěkná výslovnost, dej si jen pozor na hlásku v...",
  "words": [
    {
      "expectedWord": "I",
      "recognizedWord": "I",
      "isAccurate": true,
      "confidence": 0.98,
      "phoneticTip": ""
    }
  ]
}''';

  /// Uživatelská část dotazu k nahrávce.
  static String pronunciationRequest(String referenceText) =>
      'Zhodnoť výslovnost anglické nahrávky oproti vzorovému textu: "$referenceText"';

  /// Prompt pro Gemini TTS dle oficiální specifikace – model oddělí instrukce
  /// od mluveného textu a nečte pokyny nahlas.
  static String ttsTranscript(String text, {String? instruction}) {
    if (instruction != null && instruction.isNotEmpty) {
      return '''$instruction
Read ONLY the transcript below with natural native pronunciation. Do not read directions.

#### TRANSCRIPT
$text''';
    }
    return '''Read ONLY the transcript below with standard, clear native pronunciation. Do not read directions.

#### TRANSCRIPT
$text''';
  }

  // ── Konverzace mimo hlasového tutora ────────────────────────────────────

  /// Úvodní zpráva gramatického drilu (na zadané téma, nebo na opakující se chyby).
  static String drillKickoff([String? topicHint]) =>
      (topicHint != null && topicHint.isNotEmpty)
          ? 'Ahoj Tutore! Chci si procvičit téma: "$topicHint". Krátce mi česky vysvětli pravidlo a dej mi 3 české věty k přeložení do angličtiny.'
          : 'Ahoj Tutore! Začni prosím nový gramatický dril na mé opakující se chyby. Vyber jednu z mých slabin, stručně mi česky vysvětli pravidlo a dej mi 3 české věty k přeložení do angličtiny.';

  /// Textové pokračování konverzace nad uloženou lekcí v historii.
  static String sessionFollowUp({
    required String topic,
    required String targetLevel,
    required String conversationHistory,
    required String message,
  }) =>
      '''Jsi AJ Tudor, přátelský a trpělivý rodilý učitel angličtiny pro Čechy.
Student s tebou právě pokračuje v textovém chatu z této výukové lekce ($topic).
Úroveň studenta: $targetLevel.

Předchozí kontext konverzace v této lekci:
$conversationHistory

Nová zpráva od studenta: "$message"

Instrukce pro odpověď:
1. Reaguj přirozeně a v angličtině na to, co student píše.
2. Pokud student udělal v angličtině gramatickou nebo slovní chybu, v závěru ho jemně a srozumitelně oprav (česky vysvětli správný tvar).
3. Pokud se student ptá česky na vysvětlení gramatiky, slovíček nebo překladu, vysvětli mu to srozumitelně česky a uveď anglický příklad.
4. Odpověď udržuj přiměřeně stručnou (2-4 věty) a na konci polož přesně JEDNU otázku v angličtině, aby konverzace plynula dál.
''';

  // ── Scénáře ─────────────────────────────────────────────────────────────

  /// Systémový prompt pro scénář na míru podle popisu studenta (odpověď dle scenario schématu).
  static String customScenarioSystem({
    required String userHint,
    required String targetLevel,
    String? recurringErrors,
  }) =>
      '''Jsi Curriculum & Scenario Planner pro aplikaci AJ Tudor.
Na základě popisu od studenta vygeneruj JEDEN konverzační scénář (Role-Play).

POPIS OD STUDENTA: "$userHint"

ÚROVEŇ STUDENTA: $targetLevel
${recurringErrors != null && recurringErrors.isNotEmpty && recurringErrors != '[]' ? 'ČASTÉ CHYBY: $recurringErrors' : ''}

POŽADAVKY:
1. Vytvoř scénář, který věrně odpovídá popisu studenta.
2. Navrhni ho tak, aby přirozeně procvičoval danou situaci a slovní zásobu pro studentovu úroveň.
3. Název a popis v ČEŠTINĚ. Instrukce pro tutora v ANGLIČTINĚ (jasně definuj roli tutora a roli studenta).
''';

  /// Uživatelská zpráva k [customScenarioSystem].
  static const String customScenarioRequest =
      'Vygeneruj 1 scénář na základě mého popisu.';
}
