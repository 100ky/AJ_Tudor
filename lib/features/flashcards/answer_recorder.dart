import 'dart:async';
import '../../services/audio/audio_capture_service.dart';

/// Nahrává mluvenou odpověď na kartičku z mikrofonu.
class AnswerRecorder {
  final AudioCaptureService _capture;
  final List<int> _bytes = [];
  double _peakVolume = 0;

  /// Nejkratší nahrávka, která se posílá k vyhodnocení (0,5 s). Dvojí rychlé klepnutí
  /// na mikrofon nahrálo jen zlomek vteřiny a Gemini ho uznalo jako správnou odpověď.
  static const int minBytes = 16000;

  /// Hlasitost (0–1, jako u [AudioCaptureService.volumeStream]), od které je v nahrávce řeč.
  /// Šum místnosti v hovoru bývá kolem 0,04, řeč nad 0,1.
  static const double speechVolume = 0.09;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<double>? _volumeSub;

  AnswerRecorder(this._capture);

  /// Nahrané PCM byty (16 kHz, 16 bit, mono).
  List<int> get bytes => List<int>.from(_bytes);

  /// Nahrávka je příliš krátká na vyhodnocení (méně než 0,5 s).
  bool get isTooShort => _bytes.length < minBytes;

  /// V nahrávce byla aspoň chvíli řeč (hlasitost nad [speechVolume]).
  bool get heardSpeech => _peakVolume >= speechVolume;

  /// Spustí nahrávání; [onVolume] dostává hlasitost 0.0–1.0 pro animaci.
  Future<void> start({required void Function(double volume) onVolume}) async {
    _bytes.clear();
    _peakVolume = 0;
    await _audioSub?.cancel();
    _audioSub = _capture.audioStream.listen(_bytes.addAll);
    await _volumeSub?.cancel();
    _volumeSub = _capture.volumeStream.listen((volume) {
      if (volume > _peakVolume) _peakVolume = volume;
      onVolume(volume);
    });
    await _capture.startRecording();
  }

  /// Zastaví nahrávání a odhlásí odběr mikrofonu.
  Future<void> stop() async {
    await _capture.stopRecording();
    _audioSub?.cancel();
    _volumeSub?.cancel();
  }

  /// Zahodí nahraná data.
  void clear() => _bytes.clear();

  /// Ukončí odběry (při zavření obrazovky).
  void dispose() {
    _audioSub?.cancel();
    _volumeSub?.cancel();
  }
}
