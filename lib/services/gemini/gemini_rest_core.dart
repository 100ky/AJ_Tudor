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

/// Sleduje dočasně nedostupné (přetížené) modely a naposledy funkční model.
///
/// Každá služba má vlastní instanci, takže cooldown jednoho typu dotazu
/// (např. TTS) neblokuje modely ostatních služeb.
class ModelCooldownTracker {
  final Map<String, DateTime> _cooldownUntil = {};
  String? _preferredModel;

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
      return until == null || now.isAfter(until);
    }).toList();
    return available.isEmpty ? ordered : available;
  }

  /// Dá modelu cooldown na dobu [duration].
  void markOverloaded(String model, Duration duration) {
    _cooldownUntil[model] = DateTime.now().add(duration);
  }

  /// Zruší cooldown modelu, který uspěl; s [remember] si ho zapamatuje jako preferovaný.
  void markSuccess(String model, {bool remember = false}) {
    _cooldownUntil.remove(model);
    if (remember) _preferredModel = model;
  }

  /// Vymaže všechny cooldowny i preferovaný model.
  void clear() {
    _cooldownUntil.clear();
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
