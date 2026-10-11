/// Usek vety, ktery se na rubu karticky podtrhne.
typedef HighlightRange = ({int start, int end});

/// Nejvys tolik slov muze mit vyraz, aby se ve vete hledala i jeho jednotliva slova.
const int _maxWordsForWordMatch = 4;

/// Koncovky, se kterymi se slovo z karticky ve vete jeste pozna (take -> takes, cared).
const String _suffixes = r"(?:s|es|d|n|ly|'s|’s)";

/// Najde ve [sentence] vyraz z karticky [phrase], at ho student ve vete hned vidi.
///
/// Nejdriv se hleda cely vyraz (bez ohledu na velikost pismen). Kdyz ve vete neni,
/// u kratkeho vyrazu se hledaji jeho jednotliva slova i s beznymi koncovkami;
/// kratka slova jako "to" nebo "of" se samostatne nepodtrhavaji.
List<HighlightRange> highlightRanges(String sentence, String phrase) {
  final words = RegExp(r"[\p{L}\p{N}'’]+", unicode: true)
      .allMatches(phrase)
      .map((m) => m.group(0)!)
      .toList();
  if (sentence.trim().isEmpty || words.isEmpty) return const [];

  final whole = _matches(sentence, words.map(_literal).join(r'[\s,-]+'));
  if (whole.isNotEmpty) return whole;
  if (words.length > _maxWordsForWordMatch) return const [];

  final ranges = <HighlightRange>[];
  for (final word in words) {
    if (words.length > 1 && word.length < 3) continue;
    ranges.addAll(_matches(sentence, _inflected(word)));
  }
  return _merge(ranges);
}

List<HighlightRange> _matches(String sentence, String pattern) {
  final regex = RegExp(
    "(?<![\\p{L}\\p{N}'’])(?:$pattern)(?![\\p{L}\\p{N}])",
    caseSensitive: false,
    unicode: true,
  );
  return [
    for (final m in regex.allMatches(sentence)) (start: m.start, end: m.end),
  ];
}

/// Slovo jako regularni vyraz, ktery prijme oba druhy apostrofu.
String _literal(String word) => RegExp.escape(word).replaceAll(RegExp("['’]"), "['’]");

/// Slovo vcetne beznych anglickych tvaru (take -> takes/taking, study -> studies, run -> running).
String _inflected(String word) {
  final lower = word.toLowerCase();
  if (lower.length < 3) return _literal(word);

  final last = lower[lower.length - 1];
  final stem = _literal(lower.substring(0, lower.length - 1));
  return [
    '${_literal(lower)}(?:${RegExp.escape(last)}?(?:ing|ed|er|ers|est|en)|$_suffixes)?',
    if (lower.length >= 4 && last == 'e') '$stem(?:ing|ed|er|ers|est|en)',
    if (lower.length >= 4 && last == 'y') '${stem}i(?:es|ed|er|ers|est|ly)',
  ].join('|');
}

/// Seradi useky a slouci ty, ktere se prekryvaji nebo dotykaji.
List<HighlightRange> _merge(List<HighlightRange> ranges) {
  if (ranges.length < 2) return ranges;
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <HighlightRange>[ranges.first];
  for (final range in ranges.skip(1)) {
    final previous = merged.last;
    if (range.start <= previous.end) {
      merged[merged.length - 1] = (
        start: previous.start,
        end: range.end > previous.end ? range.end : previous.end,
      );
    } else {
      merged.add(range);
    }
  }
  return merged;
}
