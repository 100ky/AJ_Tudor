/// Český tvar podstatného jména podle počtu: [one] pro 1, [few] pro 2–4, [many] pro 0 a 5 a víc.
///
/// `czechPlural(3, 'lekce', 'lekce', 'lekcí')` vrátí „lekce“, pro 5 „lekcí“.
String czechPlural(int count, String one, String few, String many) {
  if (count == 1) return one;
  if (count >= 2 && count <= 4) return few;
  return many;
}

/// Desetinné číslo s českou čárkou: od 10 výš celé, pod 10 s jednou desetinou bez zbytečné nuly.
String czechNumber(double value) {
  if (value >= 10) return value.round().toString();
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}
