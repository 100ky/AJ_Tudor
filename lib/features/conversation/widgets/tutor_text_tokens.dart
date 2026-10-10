import '../../../services/gemini/translation_service.dart';

/// Jeden token textu tutora (slovo, interpunkce, mezera nebo zalomení řádku).
class TutorTextToken {
  /// Zobrazený text (bez markdown hvězdiček).
  final String rawText;

  /// Slovo bez okolní interpunkce a uvozovek, které se posílá k překladu.
  final String cleanWord;

  /// Zda jde slovo označit k překladu (anglické slovo mimo českou větu).
  final bool isSelectableWord;
  final bool isBold;
  final bool isItalic;

  /// Pořadí mezi označitelnými slovy, jinak -1.
  final int wordIndex;

  const TutorTextToken({
    required this.rawText,
    required this.cleanWord,
    required this.isSelectableWord,
    required this.isBold,
    required this.isItalic,
    required this.wordIndex,
  });
}

final RegExp _tokenPattern = RegExp(r'(\n|\s+|[^\s\n]+)');
final RegExp _openingMarker = RegExp(r'^([„"“(]*)(\*{1,2})(?=[^\s*])');
final RegExp _closingMarker = RegExp(r'(?<=[^\s*])(\*{1,2})([.,!?;:)“”"]*)$');
final RegExp _onlyMarkers = RegExp(r'^\*+$');
final RegExp _latinLetterOrDigit = RegExp(r'[a-zA-Z0-9]');
final RegExp _czechLetter = RegExp(r'[áčďéěíňóřšťúůýž]', caseSensitive: false);
final RegExp _sentenceEnd = RegExp(r'[.!?:][“”"]*$');

/// Česká slova bez diakritiky, která anglicky nic neznamenají – podle nich se pozná
/// česká věta, i když v ní žádná háčkovaná ani čárkovaná písmena nejsou.
const Set<String> _czechOnlyWords = {
  'je', 'jsem', 'jsi', 'jsme', 'jste', 'jsou', 'se', 'si', 'ze', 'ale', 'jak', 'tak',
  'jako', 'nebo', 'ano', 'ne', 'na', 'v', 'z', 'k', 's', 've', 'ke', 'mi', 'ti', 'mu',
  'aby', 'kde', 'kdy', 'jen', 'taky', 'tady', 'bude', 'byl', 'byla', 'bylo', 'jeho',
  'zkus', 'znovu', 'tedy', 'pak', 'proto', 'slovo', 'slova', 'jo', 'nic', 'tohle', 'toto',
};

class _WordInfo {
  final String display;
  final String clean;
  final bool isBold;
  final bool isItalic;
  final int segment;
  _WordInfo(this.display, this.clean, this.isBold, this.isItalic, this.segment);
}

/// Rozdělí text tutora na tokeny pro [InteractiveTutorText].
///
/// Tučný a kurzivní text (`**…**`, `*…*`) může zabírat víc slov, hvězdičky se nezobrazí.
/// Text se dělí na úseky: každý tučný či kurzivní text a každé uvozovky jsou samostatný úsek,
/// zbytek věty kolem nich tvoří jeden úsek až do konce věty. Úsek se dvěma českými slovy (s diakritikou nebo z [_czechOnlyWords]), nebo s převahou
/// českých slov, je česky a jeho slova označit nejdou – anglický příklad v tučném textu
/// nebo v uvozovkách uvnitř české věty ale ano.
List<TutorTextToken> tokenizeTutorText(String text) {
  final pieces = <Object>[]; // String (mezera / zalomení) nebo _WordInfo
  final czechWordCount = <int, int>{};
  final wordCount = <int, int>{};

  var bold = false;
  var italic = false;
  var quoted = false;
  var nextSegment = 0;
  var sentenceSegment = nextSegment++;
  int? spanSegment; // tučný text, kurzíva nebo uvozovky

  for (final match in _tokenPattern.allMatches(text)) {
    final raw = match.group(0) ?? '';
    if (raw.isEmpty) continue;

    if (raw == '\n' || raw.trim().isEmpty) {
      if (raw.contains('\n')) sentenceSegment = nextSegment++;
      pieces.add(raw);
      continue;
    }

    if (_onlyMarkers.hasMatch(raw)) {
      // Osamocené hvězdičky jen přepínají formátování
      if (raw.length >= 2) {
        bold = !bold;
      } else {
        italic = !italic;
      }
      spanSegment = (bold || italic || quoted) ? nextSegment++ : null;
      continue;
    }

    var display = raw;
    var opensBold = false, opensItalic = false, closesBold = false, closesItalic = false;

    final open = _openingMarker.firstMatch(display);
    if (open != null) {
      if (open.group(2)!.length == 2) {
        opensBold = !bold;
      } else {
        opensItalic = !italic;
      }
      display = open.group(1)! + display.substring(open.end);
    }
    final close = _closingMarker.firstMatch(display);
    if (close != null) {
      if (close.group(1)!.length == 2) {
        closesBold = bold || opensBold;
      } else {
        closesItalic = italic || opensItalic;
      }
      display = display.substring(0, close.start) + close.group(2)!;
    }

    final opensQuote = !quoted && RegExp(r'^[(]*[„"“]').hasMatch(display);
    final closesQuote = (quoted || opensQuote) &&
        RegExp(r'[“”"][.,!?;:)]*$').hasMatch(display) &&
        !(opensQuote && display.length == 1);

    // Vstup do tučného textu nebo uvozovek začíná nový úsek
    if (opensBold || opensItalic || opensQuote) spanSegment = nextSegment++;
    final segment = spanSegment ?? sentenceSegment;

    final isBold = bold || opensBold;
    final isItalic = italic || opensItalic;
    final clean = WordTranslationService.cleanWord(display);
    pieces.add(_WordInfo(display, clean, isBold, isItalic, segment));

    if (_latinLetterOrDigit.hasMatch(clean) || _czechLetter.hasMatch(clean)) {
      wordCount[segment] = (wordCount[segment] ?? 0) + 1;
      if (_isCzechWord(clean)) czechWordCount[segment] = (czechWordCount[segment] ?? 0) + 1;
    }

    bold = closesBold ? false : isBold;
    italic = closesItalic ? false : isItalic;
    quoted = closesQuote ? false : (quoted || opensQuote);

    // Výstup z tučného textu či uvozovek vrací do věty, konec věty začíná novou
    if (!bold && !italic && !quoted) spanSegment = null;
    if (_sentenceEnd.hasMatch(display)) sentenceSegment = nextSegment++;
  }

  // Jedno české slovo v anglické větě je spíš jméno („Hi Tomáš“), česká věta jich má víc
  bool isCzechSegment(int segment) {
    final czech = czechWordCount[segment] ?? 0;
    return czech >= 2 || (czech > 0 && czech * 2 >= (wordCount[segment] ?? 0));
  }

  final tokens = <TutorTextToken>[];
  var wordIndex = 0;
  for (final piece in pieces) {
    if (piece is String) {
      tokens.add(TutorTextToken(
        rawText: piece,
        cleanWord: '',
        isSelectableWord: false,
        isBold: false,
        isItalic: false,
        wordIndex: -1,
      ));
      continue;
    }
    final word = piece as _WordInfo;
    final selectable = word.clean.isNotEmpty &&
        _latinLetterOrDigit.hasMatch(word.clean) &&
        !_czechLetter.hasMatch(word.clean) &&
        !isCzechSegment(word.segment);
    tokens.add(TutorTextToken(
      rawText: word.display,
      cleanWord: word.clean,
      isSelectableWord: selectable,
      isBold: word.isBold,
      isItalic: word.isItalic,
      wordIndex: selectable ? wordIndex++ : -1,
    ));
  }
  return tokens;
}

bool _isCzechWord(String clean) =>
    _czechLetter.hasMatch(clean) || _czechOnlyWords.contains(clean.toLowerCase());
