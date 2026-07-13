import 'dart:async';
import 'package:record/record.dart';

class AudioCaptureService {
  final AudioRecorder _record = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  final StreamController<List<int>> _audioDataController = StreamController<List<int>>.broadcast();

  Stream<List<int>> get audioStream => _audioDataController.stream;

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      final stream = await _record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1, // Mono zvuk pro Gemini Live API
        ),
      );

      _audioStreamSubscription = stream.listen((data) {
        _audioDataController.add(data);
      });
    } else {
      throw Exception('Aplikace nemá oprávnění používat mikrofon.');
    }
  }

  Future<void> stopRecording() async {
    await _audioStreamSubscription?.cancel();
    await _record.stop();
  }

  void dispose() {
    _audioDataController.close();
    _record.dispose();
  }
}
