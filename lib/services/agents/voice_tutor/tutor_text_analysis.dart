import '../../../core/utils/logger.dart';

final RegExp _cjkCharacters = RegExp(
    r'[぀-ヿ㐀-䶿一-鿿豈-﫿ｦ-ﾟ가-힯]');

/// Odstraní asijské znaky (např. korejské 응), které STT někdy halucinuje na tichý povzdech.
String stripCjkCharacters(String text) => text.replaceAll(_cjkCharacters, '');

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// Zda promluva tutora obsahuje slova – Live API přepisuje neartikulovaný zvuk
/// (povzdech, ticho, mumlání) jen jako "...", taková replika do přepisu nepatří.
bool hasSpokenWords(String text) => _letter.hasMatch(text);

const Set<String> _fillerWords ={'uh', 'um', 'em', 'ehm', 'er', 'ah', 'hmm', 'hm', 'well'};

/// Počet slov odpovědi studenta (jen slova delší než 1 znak, bez interpunkce).
///
/// Vrátí null, pokud odpověď obsahuje jen výplňková slova (uh, um, hmm…) –
/// ta se do délky odpovědí ani do detekce frustrace nepočítají.
int? meaningfulWordCount(String userText) {
  final tokens = userText
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final isOnlyFillers = tokens.isNotEmpty && tokens.every(_fillerWords.contains);
  if (isOnlyFillers) return null;
  return tokens.where((w) => w.length > 1).length;
}

final RegExp _foreignMarkers = RegExp(r'[¿¡ñãõçßœøåæ]');

/// Zda živý přepis zjevně není česky ani anglicky (např. „¿Qué?“, korejština) – takový
/// přepis je chyba STT a nelze z něj usuzovat na délku nebo obsah odpovědi studenta.
bool looksLikeForeignTranscription(String text) =>
    _foreignMarkers.hasMatch(text.toLowerCase()) || _cjkCharacters.hasMatch(text);

final RegExp _repeatCue = RegExp(
  r'(?:zkus to|zkus|zopakuj|řekni|try saying|try it|say it|say|repeat)[^:\n]{0,30}:\s*(.+)$',
  caseSensitive: false,
  dotAll: true,
);

final RegExp _czechLetters = RegExp(r'[ěščřžýáíéúůťďň]', caseSensitive: false);

/// Vytáhne z promluvy tutora anglickou větu, kterou má student zopakovat
/// („Zkus to zopakovat: We didn't get to my demo.“), jinak vrátí null.
///
/// Věta se bere z přepisu tutora, takže se nikdy nemůže lišit od toho, co řekl hlasem.
String? extractRepeatTarget(String tutorText) {
  final matches = _repeatCue.allMatches(tutorText).toList();
  if (matches.isEmpty) return null;
  var rest = matches.last.group(1)!.trim();

  const openQuotes = '"\u201c\u201e\'';
  if (rest.isNotEmpty && openQuotes.contains(rest[0])) {
    rest = rest.substring(1);
    final close = rest.indexOf(RegExp('["\u201c\u201d\u201e]'));
    if (close >= 0) rest = rest.substring(0, close);
  }
  rest = rest.replaceAll(RegExp('["\u201c\u201d\u201e]+\$'), '').trim();

  if (rest.length < 4 || rest.length > 120) return null;
  if (rest.split(RegExp(r'\s+')).length < 2) return null;
  if (_czechLetters.hasMatch(rest)) return null;
  return rest;
}

/// Odstraní zjevné zacyklení modelu uvnitř jedné promluvy (zopakovaná věta
/// nebo její useknutá část).
String removeIntraTurnRepetition(String text) {
  if (text.isEmpty) return text;

  // Nejprve zkusíme rozdělit na věty
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
  final uniqueSentences = <String>[];

  for (final s in sentences) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) continue;

    bool isDuplicate = false;
    for (final existing in uniqueSentences) {
      final existingLower = existing.toLowerCase();
      final trimmedLower = trimmed.toLowerCase();

      // Přesná shoda
      if (existingLower == trimmedLower) {
        isDuplicate = true;
        break;
      }

      // Podřetězec (např. uťatá verze téže věty), pokud má alespoň 10 znaků
      if (trimmedLower.length > 10 && existingLower.contains(trimmedLower)) {
        isDuplicate = true;
        break;
      }
    }

    if (!isDuplicate) {
      uniqueSentences.add(trimmed);
    } else {
      L.w('Odstraněno zacyklení uvnitř věty: "$trimmed"');
    }
  }

  return uniqueSentences.join(' ');
}

Set<String> _significantWords(String text) =>
    text.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();

/// Zjistí, zda tutor opakuje některou ze svých nedávných promluv [history].
///
/// Vrátí podobnost (Jaccardův index významných slov) první opakované promluvy –
/// opakování je podobnost nad 0.45 nebo shodných prvních 20 znaků – jinak null.
double? repeatedTurnSimilarity(String text, Iterable<String> history) {
  final currentWords = _significantWords(text);
  if (currentWords.isEmpty) return null;

  for (final historyText in history) {
    final historyWords = _significantWords(historyText);
    if (historyWords.isEmpty) continue;

    final intersection = currentWords.intersection(historyWords).length;
    final union = currentWords.union(historyWords).length;
    final similarity = intersection / union;

    // Zkontrolujeme také, zda nedošlo k přesnému zkopírování delší fráze. Prefix musí být
    // dost dlouhý (40 znaků): tutor při opravě záměrně cituje správnou větu, kterou
    // už řekl dřív ("The presentation went well"), a to není stagnace.
    const prefixLength = 40;
    final hasExactMatch = text.length > prefixLength &&
        historyText.toLowerCase().contains(text.toLowerCase().substring(0, prefixLength));

    if (similarity > 0.45 || hasExactMatch) return similarity;
  }
  return null;
}
