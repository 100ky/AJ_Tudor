/// Klíč anglické strany kartičky pro hledání skoro stejných kartiček.
///
/// Malá písmena, bez interpunkce a se zkrácenými koncovkami (winterized i winterize
/// → „winteriz“, mowing → „mow“), takže rozbor po lekci nevyrobí druhou kartičku
/// jen s jiným tvarem slova (lekce 23: „winterize“ vedle „winterized“).
String cardTextKey(String backText) {
  final words = backText
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp("[’']"), '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty);
  return words.map(_stem).join(' ');
}

String _stem(String word) {
  for (final suffix in const ['ing', 'ed', 'es', 's', 'e', 'd']) {
    if (word.length - suffix.length >= 3 && word.endsWith(suffix)) {
      return word.substring(0, word.length - suffix.length);
    }
  }
  return word;
}
