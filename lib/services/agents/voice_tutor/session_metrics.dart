import '../../../core/utils/logger.dart';

/// Metriky jedné hlasové lekce pro průběžné logy a souhrn v terminálu.
class SessionMetrics {
  DateTime? _startTime;
  DateTime? _userSpeechEnd;

  /// Počet obnovení spojení během lekce.
  int reconnects = 0;

  /// Kolikrát byla detekována frustrace (opakované velmi krátké odpovědi).
  int frustrationDetections = 0;

  int _userMessages = 0;
  int _tutorMessages = 0;
  int _totalUserWords = 0;

  /// Vynuluje metriky na začátku nové lekce.
  void start() {
    _startTime = DateTime.now();
    _userSpeechEnd = null;
    reconnects = 0;
    frustrationDetections = 0;
    _userMessages = 0;
    _tutorMessages = 0;
    _totalUserWords = 0;
  }

  /// Započítá odpověď studenta o [words] slovech.
  void recordUserAnswer(int words) {
    _userMessages++;
    _totalUserWords += words;
    L.metric('user_response_words', words);
  }

  /// Započítá promluvu tutora.
  void recordTutorAnswer(String text) {
    _tutorMessages++;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    L.metric('tutor_response_words', words);
  }

  /// Student domluvil – odsud se měří reakční doba AI.
  void markUserSpeechEnd() => _userSpeechEnd = DateTime.now();

  /// Dorazila první odpověď AI – zaloguje reakční dobu od konce řeči studenta.
  void recordResponseStart() {
    final speechEnd = _userSpeechEnd;
    if (speechEnd == null) return;
    final latency = DateTime.now().difference(speechEnd).inMilliseconds;
    L.metric('ai_response_latency', latency, 'ms');
    _userSpeechEnd = null;
  }

  /// Vypíše souhrn ukončené lekce.
  void logSummary(int sessionId) {
    final startTime = _startTime;
    L.sessionEnd(
      sessionId: sessionId,
      duration: startTime != null ? DateTime.now().difference(startTime) : Duration.zero,
      userMessages: _userMessages,
      tutorMessages: _tutorMessages,
      avgUserWords: _userMessages > 0 ? _totalUserWords / _userMessages : null,
      reconnects: reconnects,
      frustrationDetections: frustrationDetections,
    );
  }
}
