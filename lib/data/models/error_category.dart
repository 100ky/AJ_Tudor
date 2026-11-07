/// Jemnější druh chyby z rozboru lekce.
///
/// Rozbor dřív dělil chyby jen na gramatiku, slovíčka a výslovnost. Podle těchto druhů
/// obrazovka Pokrok ukazuje, co se zlepšuje, a lekce z nich bere gramatický cíl.
enum ErrorCategory {
  /// Špatný čas slovesa („I go yesterday“).
  tense('tense', 'Čas slovesa'),

  /// Špatný tvar slovesa: chybějící -s ve 3. osobě, „don't“ místo „doesn't“, „I going“.
  verbForm('verb_form', 'Tvar slovesa (-s, doesn\'t)'),

  /// Špatná předložka (at/on/in a další).
  preposition('preposition', 'Předložky'),

  /// Špatná vazba nebo slovosled.
  wordOrder('word_order', 'Vazba a slovosled'),

  /// Špatně zvolené slovo.
  wordChoice('word_choice', 'Volba slova'),

  /// České slovo ve větě nebo výraz, na který se student zeptal („jak se řekne“).
  czechWord('czech_word', 'Česká slova'),

  /// Výslovnost.
  pronunciation('pronunciation', 'Výslovnost'),

  /// Cokoli jiného (člen, množné číslo…).
  other('other', 'Ostatní');

  const ErrorCategory(this.id, this.label);

  /// Hodnota v databázi a ve schématu rozboru.
  final String id;

  /// Český název pro obrazovku Pokrok.
  final String label;

  /// Druhy, ze kterých se volí gramatický cíl lekce.
  static const List<ErrorCategory> grammarGoals = [tense, verbForm, preposition, wordOrder];

  /// Gramatický cíl lekce pro tutora: co hlídat a jak se na to ptát. Prázdné u druhů,
  /// které cílem lekce nejsou.
  String get lessonGoal => switch (this) {
        tense => 'časy sloves, hlavně minulý čas (I went, I was, I have been). Ptej se na to, co se stalo včera, o víkendu nebo v práci.',
        verbForm => 'tvar slovesa: -s ve 3. osobě (he works, it doesn\'t) a průběhový tvar (I am working). Ptej se na lidi kolem něj, kolegy, na to, co dělají jeho aplikace, a co on právě dělá.',
        preposition => 'předložky at/on/in (on Monday, in the morning, at work, in test mode). Ptej se, kdy a kde se věci dějí.',
        wordOrder => 'vazby a slovosled v delších větách a otázkách. Nech ho popsat, jak něco funguje, nebo se tě na něco zeptat.',
        _ => '',
      };

  /// Druh podle hodnoty z databáze nebo rozboru; neznámá hodnota je null.
  static ErrorCategory? parse(String? id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }
}
