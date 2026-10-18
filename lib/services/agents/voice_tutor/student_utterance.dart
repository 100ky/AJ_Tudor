import 'dart:async';
import 'dart:typed_data';
import '../../../data/models/chat_message.dart';

/// Jedna replika studenta mezi `activityStart` a `activityEnd`.
///
/// Drží její zvuk pro opravný přepis a stav dvou přepisů: živého z Gemini Live
/// (přijde hned, ale občas v jiném jazyce) a opravného (přijde o chvíli později).
/// Do databáze se replika uloží jednou, až jsou známé oba.
class StudentUtterance {
  /// Nejdelší zvuk, který se posílá k opravnému přepisu (2 minuty PCM 16-bit, 16 kHz).
  static const int maxAudioBytes = 120 * 32000;

  final int sessionId;
  final BytesBuilder _audio = BytesBuilder(copy: false);
  bool _audioTooLong = false;
  final Completer<void> _settled = Completer<void>();

  /// Kdy student domluvil (čas uložení repliky, aby byla v přepisu před odpovědí tutora).
  DateTime? endedAt;

  /// Poslední replika tutora před touto, jako kontext pro opravný přepis.
  String? previousTutorLine;

  /// Živý přepis z Gemini Live.
  String liveText = '';

  /// Opravný přepis: null = nedoběhl nebo selhal, prázdný = v nahrávce není řeč.
  String? correctedText;
  bool correctionDone = false;

  /// Živý přepis je úplný (tutor začal odpovídat, nebo spojení skončilo).
  bool liveDone = false;

  /// Bublina repliky v UI.
  ChatMessage? message;

  /// Kam bublinu vložit, když živý přepis nepřišel vůbec (před odpověď tutora).
  int? insertIndex;

  bool saved = false;

  /// Kolik souvislého hlasu replika zatím má (krátké repliky se před odesláním ověřují).
  int voicedMs = 0;

  // Pořadí opravného přepisu; výsledek staršího přepisu po znovuotevření repliky se zahodí.
  int _correctionRound = 0;

  // Zvuk nahraný před odesláním serveru (krátká replika čeká na ověření, že jde o řeč).
  final List<List<int>> _unsent = [];

  // Ověření krátké repliky opravným přepisem; při další řeči se zruší.
  Future<String?>? _verification;
  int _verificationRound = 0;

  StudentUtterance({required this.sessionId});

  void addAudio(List<int> chunk) {
    if (_audioTooLong) return;
    if (_audio.length + chunk.length > maxAudioBytes) {
      _audioTooLong = true;
      return;
    }
    _audio.add(chunk);
  }

  /// Nahraje blok zvuku, který se serveru pošle, až replika projde ověřením.
  void addUnsent(List<int> chunk) {
    addAudio(chunk);
    _unsent.add(chunk);
  }

  /// Vrátí dosud neodeslané bloky (od nejstaršího) a zapomene je.
  List<List<int>> takeUnsent() {
    final chunks = List<List<int>>.of(_unsent);
    _unsent.clear();
    return chunks;
  }

  /// Rozběhnuté ověření, že krátká replika je řeč (výsledek jako u opravného přepisu).
  Future<String?>? get verification => _verification;
  int get verificationRound => _verificationRound;

  void startVerification(Future<String?> verification) {
    _verificationRound++;
    _verification = verification;
  }

  /// Student mluví dál: ověření z předchozí pauzy už neplatí.
  void cancelVerification() {
    if (_verification == null) return;
    _verificationRound++;
    _verification = null;
  }

  bool isVerificationCurrent(int round) => _verification != null && round == _verificationRound;

  /// Celý dosavadní zvuk k opravnému přepisu; prázdný, když replika byla moc dlouhá.
  Uint8List audioBytes() => _audioTooLong ? Uint8List(0) : _audio.toBytes();

  /// Délka dosud nahraného zvuku v ms (PCM 16-bit, 16 kHz, mono = 32 bajtů na ms).
  int get audioMs => (_audioTooLong ? maxAudioBytes : _audio.length) ~/ 32;

  /// Student mluví dál dřív, než tutor odpověděl: model to bere jako jeden tah,
  /// takže replika pokračuje a opravný přepis se udělá znovu z celého zvuku.
  void reopen() {
    endedAt = null;
    correctedText = null;
    correctionDone = false;
    _correctionRound++;
  }

  /// Začne nový opravný přepis a vrátí jeho pořadí pro [isCurrentRound].
  int beginCorrection() => ++_correctionRound;

  bool isCurrentRound(int round) => round == _correctionRound;

  /// Text k uložení: opravný přepis, a když chybí, živý přepis.
  ///
  /// Když opravný přepis v nahrávce řeč neslyšel, krátký živý přepis se zahodí –
  /// živý přepis si na ruch (nádech, klepnutí) vymýšlí „¿Qué?“. Delší živý přepis
  /// zůstane, tam se spíš spletl opravný přepis.
  String get finalText {
    final corrected = correctedText?.trim();
    final live = liveText.trim();
    if (correctionDone && corrected != null) {
      if (corrected.isNotEmpty) return corrected;
      if (_wordCount(live) <= 2) return '';
    }
    return live;
  }

  static int _wordCount(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  bool get readyToSave => correctionDone && liveDone && !saved;

  /// Dokončí se, až je replika uložená (nebo zahozená).
  Future<void> get settled => _settled.future;

  void markSettled() {
    if (!_settled.isCompleted) _settled.complete();
  }
}
