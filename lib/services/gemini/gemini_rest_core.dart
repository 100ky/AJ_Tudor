import 'dart:convert';

import 'package:dio/dio.dart';

/// Druh chyby Gemini REST API – určuje, jak se služba zachová v kaskádě záložních modelů.
enum GeminiErrorKind {
  /// Neplatný nebo neoprávněný API klíč (401/403) – další modely nemá smysl zkoušet.
  auth,

  /// Model neexistuje nebo není pro klíč dostupný (404).
  notFound,

  /// Dočasné přetížení, výpadek spojení nebo timeout (0/429/500/503) – model dostane cooldown.
  overloaded,

  /// Ostatní chyby (např. 400 Bad Request).
  other,
}

/// Roztřídí [DioException] z volání Gemini REST API.
GeminiErrorKind classifyGeminiError(DioException e) {
  final statusCode = e.response?.statusCode ?? 0;
  if (statusCode == 401 || statusCode == 403) return GeminiErrorKind.auth;
  if (statusCode == 404) return GeminiErrorKind.notFound;
  // statusCode 0 = server neodpověděl (výpadek spojení nebo timeout)
  if (statusCode == 0 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 503 ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return GeminiErrorKind.overloaded;
  }
  return GeminiErrorKind.other;
}

/// Zda chyba 429 hlásí vyčerpaný denní limit modelu (`quotaId` …PerDay…).
///
/// Bezplatná úroveň má u gemini-3.8-flash a gemini-3.6-flash jen 20 požadavků denně,
/// flash-lite modely 500. Minutový limit vrací 429 taky, ale bez `PerDay`.
bool isDailyQuotaError(DioException e) {
  if (e.response?.statusCode != 429) return false;
  final data = e.response?.data;
  String text;
  try {
    text = data is String ? data : jsonEncode(data);
  } catch (_) {
    text = data.toString();
  }
  return text.contains('PerDay');
}

/// Kdy se obnoví denní kvóta: o půlnoci pacifického času, tedy v 8:00 UTC
/// (v letním čase už v 7:00 UTC, model se pak vynechá o hodinu déle).
DateTime nextDailyQuotaReset(DateTime now) {
  final utc = now.toUtc();
  final today = DateTime.utc(utc.year, utc.month, utc.day, 8);
  return today.isAfter(utc) ? today : today.add(const Duration(days: 1));
}

/// Jak dlouho model po chybě [e] vynechat: při vyčerpaném denním limitu až do jeho obnovy,
/// při minutovém limitu minutu, jinak [otherwise] (přetížení, timeout).
Duration cooldownAfter(DioException e, {required Duration otherwise, DateTime? now}) {
  final at = now ?? DateTime.now();
  if (isDailyQuotaError(e)) return nextDailyQuotaReset(at).difference(at.toUtc());
  if (e.response?.statusCode == 429) return const Duration(minutes: 1);
  return otherwise;
}

/// Vytáhne čitelnou chybovou zprávu z [DioException] (pole `error.message` v těle odpovědi).
String geminiErrorMessage(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?['message']?.toString() ?? e.message ?? e.toString();
    }
  } catch (_) {}
  return e.message ?? e.toString();
}

/// Odstraní z textové odpovědi modelu HTML/XML tagy (např. `</code>`) a markdown
/// (`**`, `*`, `` ` ``), které model občas přidá, a sjednotí mezery do jednoho řádku.
String stripModelFormatting(String raw) => raw
    .replaceAll(RegExp(r'<[^<>]*>'), '')
    .replaceAll(RegExp(r'[`*]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Sleduje dočasně nedostupné (přetížené) modely a naposledy funkční model.
///
/// Každá služba má vlastní instanci, takže cooldown jednoho typu dotazu
/// (např. TTS) neblokuje modely ostatních služeb.
class ModelCooldownTracker {
  final Map<String, DateTime> _cooldownUntil = {};
  String? _preferredModel;

  // Denní kvóta platí pro model v celém projektu: když ji vyčerpá jedna služba,
  // vynechají ho do obnovy kvóty i ostatní (dřív to zkoušely každé 2–3 minuty znovu).
  static final Map<String, DateTime> _dailyQuotaUntil = {};

  /// Naposledy úspěšně použitý model (pokud si ho služba pamatuje přes [markSuccess]).
  String? get preferredModel => _preferredModel;

  /// Vrátí pořadí modelů k vyzkoušení.
  ///
  /// S [preferLastWorking] jde naposledy funkční model jako první. Modely v cooldownu
  /// se přeskočí; pokud jsou v cooldownu všechny, vrátí se celé pořadí.
  List<String> order(Iterable<String> candidates, {bool preferLastWorking = false}) {
    final ordered = <String>[];
    final preferred = _preferredModel;
    if (preferLastWorking && preferred != null && candidates.contains(preferred)) {
      ordered.add(preferred);
    }
    for (final model in candidates) {
      if (!ordered.contains(model)) ordered.add(model);
    }

    final now = DateTime.now();
    final available = ordered.where((model) {
      final until = _cooldownUntil[model];
      final quotaUntil = _dailyQuotaUntil[model];
      return (until == null || now.isAfter(until)) && (quotaUntil == null || now.isAfter(quotaUntil));
    }).toList();
    return available.isEmpty ? ordered : available;
  }

  /// Dá modelu cooldown na dobu [duration].
  void markOverloaded(String model, Duration duration) {
    _cooldownUntil[model] = DateTime.now().add(duration);
  }

  /// Model selhal chybou [e]: dostane cooldown podle [cooldownAfter]. Vyčerpaný denní
  /// limit ho vyřadí ve všech službách až do obnovy kvóty. Vrátí délku cooldownu.
  Duration markFailure(String model, DioException e, {required Duration otherwise}) {
    final cooldown = cooldownAfter(e, otherwise: otherwise);
    markOverloaded(model, cooldown);
    if (isDailyQuotaError(e)) _dailyQuotaUntil[model] = DateTime.now().add(cooldown);
    return cooldown;
  }

  /// Zruší cooldown modelu, který uspěl; s [remember] si ho zapamatuje jako preferovaný.
  void markSuccess(String model, {bool remember = false}) {
    _cooldownUntil.remove(model);
    if (remember) _preferredModel = model;
  }

  /// Vymaže všechny cooldowny i preferovaný model (i sdílenou denní kvótu, pro testy).
  void clear() {
    _cooldownUntil.clear();
    _dailyQuotaUntil.clear();
    _preferredModel = null;
  }
}

/// Společný HTTP klient pro Gemini REST endpoint `generateContent`.
class GeminiRestCore {
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final Dio _dio;

  GeminiRestCore({
    required Duration connectTimeout,
    required Duration receiveTimeout,
  }) : _dio = Dio(BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ));

  /// Zavolá `generateContent` modelu [model] a vrátí dekódované JSON tělo odpovědi.
  ///
  /// Chyby HTTP propadají jako [DioException] – roztřídí je [classifyGeminiError].
  Future<Map<String, dynamic>?> generateContent({
    required String apiKey,
    required String model,
    required Map<String, dynamic> body,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/$model:generateContent?key=$apiKey',
      data: body,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      ),
    );
    return response.data;
  }

  /// Části (`parts`) první kandidátní odpovědi, nebo null.
  static List<dynamic>? firstCandidateParts(Map<String, dynamic>? data) {
    final candidates = data?['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    return candidates[0]['content']?['parts'] as List?;
  }

  /// Text první části první kandidátní odpovědi, nebo null.
  static String? extractText(Map<String, dynamic>? data) {
    final parts = firstCandidateParts(data);
    if (parts == null || parts.isEmpty) return null;
    final text = parts[0]['text']?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Jako [extractText], ale místo null vyhodí výjimku s popisem, co v odpovědi chybí.
  static String requireText(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Prázdná odpověď od serveru');
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Žádní kandidáti v odpovědi: $data');
    }
    final content = candidates[0]['content'];
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Žádné části v odpovědi: $content');
    }
    final text = parts[0]['text']?.toString();
    if (text == null || text.isEmpty) throw Exception('Prázdný text v odpovědi');
    return text;
  }
}
