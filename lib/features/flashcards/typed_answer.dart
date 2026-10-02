import 'dart:math' as math;

/// Napsaná odpověď studenta na kartičku a její shoda se správným řešením.
///
/// Porovnává se lokálně (Levenshteinova vzdálenost po normalizaci), bez volání AI,
/// takže písemná odpověď funguje i offline nebo když selže hodnocení výslovnosti.
class TypedAnswer {
  /// Text, který student napsal.
  final String text;

  /// Shoda se správným řešením (0.0–1.0).
  final double score;

  const TypedAnswer({required this.text, required this.score});

  /// Porovná [typed] s řešením [expected]. Řešení může mít varianty oddělené „ / “.
  factory TypedAnswer.evaluate(String typed, String expected) {
    final answer = _normalize(typed);
    final variants = [expected, ...expected.split(' / ')];

    var best = 0.0;
    for (final variant in variants) {
      final target = _normalize(variant);
      if (target.isEmpty || answer.isEmpty) continue;
      best = math.max(best, _similarity(answer, target));
    }
    return TypedAnswer(text: typed.trim(), score: best);
  }

  /// Malá písmena, jednotné apostrofy, bez interpunkce a bez úvodního „to “ u sloves.
  static String _normalize(String s) {
    var t = s.toLowerCase().replaceAll(RegExp(r'[’‘`´]'), "'");
    t = t.replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.startsWith('to ')) t = t.substring(3);
    return t;
  }

  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final maxLen = math.max(a.length, b.length);
    return 1.0 - _levenshtein(a, b) / maxLen;
  }

  static int _levenshtein(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }
}
