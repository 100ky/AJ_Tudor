import 'dart:convert';

final RegExp _jsonFenceOpen = RegExp(r'^```json\s*', multiLine: true);
final RegExp _fence = RegExp(r'^```\s*', multiLine: true);

/// Odstraní markdown ohraničení kódu (```json … ```), které modely občas přidají kolem JSONu.
String stripCodeFences(String raw) =>
    raw.replaceAll(_jsonFenceOpen, '').replaceAll(_fence, '').trim();

/// Dekóduje JSON z textové odpovědi modelu (toleruje ```json ohraničení).
dynamic decodeModelJson(String raw) => jsonDecode(stripCodeFences(raw));
