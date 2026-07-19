import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioPlaybackService {
  bool _isInitialized = false;
  bool _isSupported = true;

  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;
  DateTime _lastVolumeUpdate = DateTime.now();

  Future<void> init() async {
    if (!_isInitialized && _isSupported) {
      try {
        // Gemini Live API posílá zvuk v 24kHz PCM 16-bit Mono
        await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
        _isInitialized = true;
      } on MissingPluginException {
        debugPrint('Varování: Audio plugin není na této platformě podporován (např. Windows). Zvuk se nebude přehrávat.');
        _isSupported = false;
      } catch (e) {
        debugPrint('Chyba při inicializaci audia: $e');
        _isSupported = false;
      }
    }
  }

  Future<void> playPcmData(List<int> pcmBytes) async {
    if (!_isInitialized && _isSupported) await init();
    if (!_isSupported) return;
    
    // Ensure even length for 16-bit PCM (2 bytes per sample)
    List<int> safeBytes = pcmBytes;
    if (safeBytes.length % 2 != 0) {
      safeBytes = safeBytes.sublist(0, safeBytes.length - 1);
    }
    if (safeBytes.isEmpty) return;
    
    try {
      // Výpočet hlasitosti pro vizualizaci
      _calculateAndEmitVolume(safeBytes);

      // Převod surových bytů na PcmArrayInt16
      final uint8List = Uint8List.fromList(safeBytes);
      final byteData = ByteData.sublistView(uint8List);
      final pcmArray = PcmArrayInt16(bytes: byteData);
      
      await FlutterPcmSound.feed(pcmArray);
    } catch (e) {
      debugPrint('Chyba při přehrávání audia: $e');
    }
  }

  void _calculateAndEmitVolume(List<int> buffer) {
    if (buffer.isEmpty) return;

    // THROTTLING pro UI plynulost
    final now = DateTime.now();
    if (now.difference(_lastVolumeUpdate).inMilliseconds < 33) {
      return;
    }
    _lastVolumeUpdate = now;
    
    final int sampleCount = buffer.length ~/ 2;
    if (sampleCount == 0) return; // Prevent division by zero
    
    double sum = 0;
    final byteData = ByteData.sublistView(Uint8List.fromList(buffer));
    
    for (int i = 0; i < buffer.length - 1; i += 2) {
      final int sample = byteData.getInt16(i, Endian.little);
      sum += sample * sample;
    }
    
    final double rms = math.sqrt(sum / sampleCount);
    double volume = math.sqrt(rms / 32768.0);
    
    // Safety check against NaN to avoid crashes on clamp()
    if (volume.isNaN) {
      volume = 0.0;
    }
    
    _volumeController.add(volume.clamp(0.0, 1.0));
  }

  Future<void> interrupt() async {
    await stop();
  }

  Future<void> stop() async {
    if (_isSupported && _isInitialized) {
      try {
        await FlutterPcmSound.release();
        _volumeController.add(0.0);
      } catch (_) {}
    }
    _isInitialized = false;
  }

  void dispose() {
    _volumeController.close();
  }
}
