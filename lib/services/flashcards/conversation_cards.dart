/// Kartička, kterou může splnit živý hovor: český výraz a jeho anglický cíl.
class ConversationCard {
  /// ID kartičky v databázi.
  final int id;

  /// Česká strana (líc kartičky).
  final String czech;

  /// Anglický cílový výraz (rub kartičky).
  final String english;

  /// Výrazy, které kartičku v replice splní (z rubu bez závorek, jednotlivé varianty).
  final List<RegExp> patterns;

  /// Vytvoří kartičku pro hovor; vzory se odvodí z [english].
  ConversationCard({required this.id, required this.czech, required this.english})
      : patterns = ConversationCards.targetPatterns(english);

  /// Zda [normalizedText] (viz [ConversationCards.normalize]) obsahuje cílový výraz.
  bool matches(String normalizedText) => patterns.any((p) => p.hasMatch(normalizedText));
}

/// Dnešní kartičky v živém hovoru (pokec).
///
/// Režisér dostane zásobu kartiček, které jdou dnes na opakování, a když se některá hodí
/// k tématu, navede tutora k situaci, ve které ji student použije. Kartičku splní replika,
/// ve které student cílový výraz řekl sám: tutor ho v posledních replikách neřekl, takže
/// nejde o zopakování po něm. Kontrola nevolá model.
class ConversationCards {
  /// Kolik kartiček najednou dostane režisér.
  static const int poolSize = 15;

  /// Nejdelší cílový výraz, který se v hovoru ověřuje. Delší kartičky jsou celé věty
  /// a student je skoro nikdy neřekne doslova.
  static const int maxTargetWords = 4;

  /// Jednoslovný cíl musí mít aspoň tolik písmen. Krátká běžná slova („go“, „has“,
  /// „fun“) student řekne pořád, takže by kartičku splnil náhodou.
  static const int minSingleWordLetters = 6;

  /// Kolik posledních replik tutora se kontroluje, jestli výraz neřekl on.
  static const int tutorLinesChecked = 4;

  /// Nejkratší odstup mezi dvěma vpletenými kartičkami, ať hovor nesklouzne do zkoušení.
  static const Duration cardSpacing = Duration(minutes: 2);

  final List<ConversationCard> _cards;
  final DateTime Function() _clock;
  final Set<int> _woven = {};
  final List<ConversationCard> _completed = [];
  DateTime? _lastWovenAt;

  /// Kartičky pro hovor; ty, které se v hovoru ověřit nedají, vynechá.
  /// [cards] mají být seřazené od nejdéle čekající.
  ConversationCards(Iterable<ConversationCard> cards, {DateTime Function()? clock})
      : _cards = cards.where((c) => c.patterns.isNotEmpty).toList(),
        _clock = clock ?? DateTime.now;

  /// Všechny kartičky, které může hovor splnit.
  List<ConversationCard> get cards => List.unmodifiable(_cards);

  /// Kartičky splněné v tomto hovoru.
  List<ConversationCard> get completed => List.unmodifiable(_completed);

  /// Zásoba pro režiséra: nesplněné a dosud nevpletené kartičky, nejstarší první.
  /// Prázdná, dokud od poslední vpletené kartičky neuplynul [cardSpacing].
  List<ConversationCard> directorPool() {
    final last = _lastWovenAt;
    if (last != null && _clock().difference(last) < cardSpacing) return const [];
    return _cards
        .where((c) => !_woven.contains(c.id) && !_completed.any((d) => d.id == c.id))
        .take(poolSize)
        .toList();
  }

  /// Kartička podle ID, jinak null.
  ConversationCard? byId(int? id) {
    if (id == null) return null;
    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// Režisér kartičku vpletl do rady tutorovi; znovu ji v tomto hovoru nedostane.
  void markWoven(ConversationCard card) {
    _woven.add(card.id);
    _lastWovenAt = _clock();
  }

  /// Označí a vrátí kartičky, které splnila replika studenta [studentText].
  ///
  /// [recentTutorLines] jsou poslední repliky tutora před replikou studenta: výraz,
  /// který v nich zazněl, student jen zopakoval a kartičku nesplní.
  List<ConversationCard> completeBy(String studentText, {Iterable<String> recentTutorLines = const []}) {
    final said = normalize(studentText);
    if (said.isEmpty) return const [];
    final tutorSaid = recentTutorLines.map(normalize).toList();
    final done = <ConversationCard>[];
    for (final card in _cards) {
      if (_completed.any((d) => d.id == card.id)) continue;
      if (!card.matches(said)) continue;
      if (tutorSaid.any(card.matches)) continue;
      _completed.add(card);
      done.add(card);
    }
    return done;
  }

  /// Text pro porovnání: malá písmena, rozepsané zkratky (don't → do not, I'm → I am),
  /// bez apostrofů a interpunkce, mezery sjednocené.
  static String normalize(String text) {
    var s = text.toLowerCase().replaceAll(RegExp('[’‘`´]'), "'");
    s = s
        .replaceAll(RegExp(r"\bcan't\b"), 'can not')
        .replaceAll(RegExp(r'\bcannot\b'), 'can not')
        .replaceAll(RegExp(r"\bwon't\b"), 'will not')
        .replaceAll("n't", ' not')
        .replaceAll("'m", ' am')
        .replaceAll("'re", ' are')
        .replaceAll("'ve", ' have')
        .replaceAll("'ll", ' will')
        .replaceAll("'d", ' would')
        .replaceAll("'", '');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return s.trim();
  }

  static const String _word = '[a-z0-9]+';

  /// Zástupná slova z rubu kartičky a co za ně student může říct.
  static const Map<String, String> _placeholders = {
    'ones': '(?:my|your|his|her|its|our|their|ones)',
    'oneself': '(?:myself|yourself|himself|herself|itself|ourselves|yourselves|themselves|oneself)',
    'someone': _word,
    'somebody': _word,
    'sb': _word,
    'something': '$_word(?: $_word)?',
    'sth': '$_word(?: $_word)?',
  };

  /// Vzory cílového výrazu z rubu kartičky. Varianty odděluje `/` nebo `;`, text
  /// v závorkách je poznámka. Úvodní „to“ u slovesa se vynechá a „be“ smí být
  /// v jakémkoli tvaru („be created for“ splní i „was created for“). Prázdné, když se
  /// výraz v hovoru ověřit nedá (moc dlouhý, nebo krátké běžné slovo).
  static List<RegExp> targetPatterns(String backText) {
    final withoutNotes = backText.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final patterns = <RegExp>[];
    for (final variant in withoutNotes.split(RegExp('[/;]'))) {
      var words = normalize(variant).split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length > 1 && words.first == 'to') words = words.sublist(1);
      if (words.isEmpty || words.length > maxTargetWords) continue;
      final literal = words.where((w) => !_placeholders.containsKey(w)).toList();
      if (literal.isEmpty) continue;
      if (words.length == 1 && words.single.length < minSingleWordLetters) continue;
      final parts = [
        for (var i = 0; i < words.length; i++)
          if (i == 0 && words[i] == 'be' && words.length > 1)
            '(?:be|am|is|are|was|were|been|being)'
          else
            _placeholders[words[i]] ?? RegExp.escape(words[i]),
      ];
      patterns.add(RegExp('(?:^| )${parts.join(' ')}(?= |\$)'));
    }
    return patterns;
  }
}
