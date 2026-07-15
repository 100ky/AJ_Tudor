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
      await _captureService.startRecording();
      _captureSubscription = _captureService.audioStream.listen(onAudioChunk);
    } catch (e, stack) {
      L.e('Selhalo startování nahrávání', e, stack);
      rethrow;
    }
  }

  Future<void> stop() async {
    L.i('Ukončování audio session...');
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    await _captureService.stopRecording();
    // Přehrávání stopovat nemusíme explicitně, pokud nechceme useknout probíhající zvuk, 
    // ale můžeme vyčistit buffery pokud by to bylo potřeba.
  }

  void playPcm(List<int> bytes) {
    _playbackService.playPcmData(bytes);
  }
}

final audioSessionControllerProvider = Provider<AudioSessionController>((ref) {
  final capture = ref.watch(audioCaptureServiceProvider);
  final playback = ref.watch(audioPlaybackServiceProvider);
  return AudioSessionController(capture, playback);
});
