import '../../../core/utils/logger.dart';

final RegExp _cjkCharacters = RegExp(
    r'[぀-ヿ㐀-䶿一-鿿豈-﫿ｦ-ﾟ가-힯]');

/// Odstraní asijské znaky (např. korejské 응), které STT někdy halucinuje na tichý povzdech.
String stripCjkCharacters(String text) => text.replaceAll(_cjkCharacters, '');

const Set<String> _fillerWords = {'uh', 'um', 'em', 'ehm', 'er', 'ah', 'hmm', 'hm', 'well'};

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

    // Zkontrolujeme také, zda nedošlo k přesnému zkopírování delší fráze (víc než 20 znaků)
    final hasExactMatch = text.length > 20 &&
        historyText.toLowerCase().contains(text.toLowerCase().substring(0, 20));

    if (similarity > 0.45 || hasExactMatch) return similarity;
  }
  return null;
}
