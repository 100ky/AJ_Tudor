import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_capture_service.dart';
import 'audio_playback_service.dart';
import '../../core/utils/logger.dart';
import '../../providers/audio_provider.dart';

/// Zapouzdřuje logiku nahrávání a přehrávání pro jednu lekci.
class AudioSessionController {
  final AudioCaptureService _captureService;
  final AudioPlaybackService _playbackService;
  
  StreamSubscription<List<int>>? _captureSubscription;

  AudioSessionController(this._captureService, this._playbackService);

  Future<void> start({required Function(List<int>) onAudioChunk}) async {
    L.i('Startování audio session...');
    try {
      await _captureSubscription?.cancel();
      await _captureService.startRecording();
      _captureSubscription = _captureService.audioStream.listen(onAudioChunk);
    } catch (e, stack) {
      L.e('Selhalo startování nahrávání', e, stack);
      rethrow;
    }
  }

  /// Ověří, zda mikrofon nahrává, a pokud ne (např. po návratu z pozadí), spustí jej.
  Future<void> ensureRecording({required Function(List<int>) onAudioChunk}) async {
    final recording = await _captureService.isRecording();
    if (!recording || _captureSubscription == null) {
      L.i('Mikrofon nebyl aktivní, restartuji nahrávání...');
      await start(onAudioChunk: onAudioChunk);
    }
  }

  Future<void> stop() async {
    L.i('Ukončování audio session...');
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    await _captureService.stopRecording();
    await _playbackService.stop();
  }

  Stream<double> get captureVolumeStream => _captureService.volumeStream;
  Stream<double> get playbackVolumeStream => _playbackService.volumeStream;

  /// Indikuje, zda se aktuálně fyzicky přehrává zvuk z reproduktoru
  bool get isPlaying => _playbackService.isPlaying;

  void playPcm(List<int> bytes) {
    _playbackService.playPcmData(bytes);
  }
}

final audioSessionControllerProvider = Provider<AudioSessionController>((ref) {
  final capture = ref.watch(audioCaptureServiceProvider);
  final playback = ref.watch(audioPlaybackServiceProvider);
  return AudioSessionController(capture, playback);
});
