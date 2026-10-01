import 'dart:async';
import '../../services/audio/audio_capture_service.dart';

/// Nahrává mluvenou odpověď na kartičku z mikrofonu.
class AnswerRecorder {
  final AudioCaptureService _capture;
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<double>? _volumeSub;

  AnswerRecorder(this._capture);

  /// Nahrané PCM byty (16 kHz, 16 bit, mono).
  List<int> get bytes => List<int>.from(_bytes);

  /// Nahrávka je příliš krátká na vyhodnocení (méně než 0,05 s).
  bool get isTooShort => _bytes.length < 1600;

  /// Spustí nahrávání; [onVolume] dostává hlasitost 0.0–1.0 pro animaci.
  Future<void> start({required void Function(double volume) onVolume}) async {
    _bytes.clear();
    await _audioSub?.cancel();
    _audioSub = _capture.audioStream.listen(_bytes.addAll);
    await _volumeSub?.cancel();
    _volumeSub = _capture.volumeStream.listen(onVolume);
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
