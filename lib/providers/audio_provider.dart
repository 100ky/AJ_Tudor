import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio/audio_capture_service.dart';
import '../services/audio/audio_playback_service.dart';

final audioCaptureServiceProvider = Provider<AudioCaptureService>((ref) {
  final service = AudioCaptureService();
  ref.onDispose(() => service.dispose());
  return service;
});

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() => service.stop());
  return service;
});
