import '../../../core/utils/logger.dart';

/// Metriky jedné hlasové lekce pro průběžné logy a souhrn v terminálu.
class SessionMetrics {
  /// [now] nahrazuje hodiny v testech.
  SessionMetrics({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  DateTime? _startTime;
  DateTime? _userSpeechEnd;

  /// Počet obnovení spojení během lekce.
  int reconnects = 0;

  /// Kolikrát byla detekována frustrace (opakované velmi krátké odpovědi).
  int frustrationDetections = 0;

  int _userMessages = 0;
  int _tutorMessages = 0;
  int _totalUserWords = 0;
  final List<int> _responseLatenciesMs = [];

  static final RegExp _whitespace = RegExp(r'\s+');

  static int _wordCount(String text) => text.split(_whitespace).where((w) => w.isNotEmpty).length;

  /// Vynuluje metriky na začátku nové lekce.
  void start() {
    _startTime = _now();
    _userSpeechEnd = null;
    reconnects = 0;
    frustrationDetections = 0;
    _userMessages = 0;
    _tutorMessages = 0;
    _totalUserWords = 0;
    _responseLatenciesMs.clear();
  }

  /// Započítá repliku studenta [text] tak, jak se uložila do přepisu lekce.
  ///
  /// Dřív se počítal jen živý přepis krátkých nahrávek (do 3 s i s tichem na konci),
  /// takže souhrn lekce hlásil „user: 0“ a průměrnou délku odpovědi neznal.
  void recordUserReply(String text) {
    final words = _wordCount(text);
    _userMessages++;
    _totalUserWords += words;
    L.metric('user_response_words', words);
  }

  /// Počet započítaných replik studenta.
  int get userReplies => _userMessages;

  /// Započítá promluvu tutora.
  void recordTutorAnswer(String text) {
    _tutorMessages++;
    L.metric('tutor_response_words', _wordCount(text));
  }

  /// Student domluvil (aplikace ohlásila serveru konec řeči) – odsud se měří reakční doba AI.
  void markUserSpeechEnd() => _userSpeechEnd = _now();

  /// Student domluvil a odpověď AI ještě nezačala.
  bool get isAwaitingResponse => _userSpeechEnd != null;

  /// Reakční doby AI v této lekci v milisekundách, jak šly za sebou.
  List<int> get responseLatenciesMs => List.unmodifiable(_responseLatenciesMs);

  /// Prostřední reakční doba AI v této lekci; null, dokud AI na nic neodpověděla.
  int? get medianResponseLatencyMs {
    if (_responseLatenciesMs.isEmpty) return null;
    final sorted = [..._responseLatenciesMs]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Dorazila první odpověď AI – zaloguje reakční dobu od konce řeči studenta.
  void recordResponseStart() {
    final speechEnd = _userSpeechEnd;
    if (speechEnd == null) return;
    final latency = _now().difference(speechEnd).inMilliseconds;
    _responseLatenciesMs.add(latency);
    L.metric('ai_response_latency', latency, 'ms');
    _userSpeechEnd = null;
  }

  /// Vypíše souhrn ukončené lekce.
  void logSummary(int sessionId) {
    final startTime = _startTime;
    L.sessionEnd(
      sessionId: sessionId,
      duration: startTime != null ? _now().difference(startTime) : Duration.zero,
      userMessages: _userMessages,
      tutorMessages: _tutorMessages,
      avgUserWords: _userMessages > 0 ? _totalUserWords / _userMessages : null,
      reconnects: reconnects,
      frustrationDetections: frustrationDetections,
    );
    final median = medianResponseLatencyMs;
    if (median != null) {
      final slowest = _responseLatenciesMs.reduce((a, b) => a > b ? a : b);
      L.metric('ai_response_latency_median', median, 'ms (nejdelší $slowest ms, odpovědí ${_responseLatenciesMs.length})');
    }
  }
}
