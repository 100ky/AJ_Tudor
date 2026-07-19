import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioCaptureService {
  final AudioRecorder _record = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  final StreamController<List<int>> _audioDataController = StreamController<List<int>>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  DateTime _lastVolumeUpdate = DateTime.now();

  Stream<List<int>> get audioStream => _audioDataController.stream;
  Stream<double> get volumeStream => _volumeController.stream;

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      final stream = await _record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1, // Mono zvuk pro Gemini Live API
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
      );

      _audioStreamSubscription = stream.listen((data) {
        _audioDataController.add(data);
        _calculateAndEmitVolume(data);
      });
    } else {
      throw Exception('Aplikace nemá oprávnění používat mikrofon.');
    }
  }

  void _calculateAndEmitVolume(List<int> buffer) {
    if (buffer.isEmpty) return;

    // THROTTLING: Omezíme aktualizace hlasitosti na max ~30 FPS, aby se nezahltilo UI vlákno.
    final now = DateTime.now();
    if (now.difference(_lastVolumeUpdate).inMilliseconds < 33) {
      return;
    }
    _lastVolumeUpdate = now;
    
    double sum = 0;
    final int sampleCount = buffer.length ~/ 2;
    
    final byteData = ByteData.sublistView(Uint8List.fromList(buffer));
    
    for (int i = 0; i < buffer.length - 1; i += 2) {
      // PCM 16-bit Little Endian
      final int sample = byteData.getInt16(i, Endian.little);
      sum += sample * sample;
    }
    
    final double rms = math.sqrt(sum / sampleCount);
    
    // Vylepšená normalizace hlasitosti pro vizualizaci.
    // Pro PCM 16-bit je max hodnota 32768. 
    // Použijeme odmocninu pro zvýšení citlivosti při nižších hlasitostech,
    // aby byl waveform živější i při běžné mluvě.
    double volume = math.sqrt(rms / 32768.0); 
    _volumeController.add(volume.clamp(0.0, 1.0));
  }

  Future<void> stopRecording() async {
    await _audioStreamSubscription?.cancel();
    await _record.stop();
    _volumeController.add(0.0);
  }

  void dispose() {
    _audioDataController.close();
    _volumeController.close();
    _record.dispose();
  }
}
