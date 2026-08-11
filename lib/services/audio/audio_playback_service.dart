import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class _VolumeQueueItem {
  final DateTime scheduledTime;
  final double volume;
  _VolumeQueueItem(this.scheduledTime, this.volume);
}

class AudioPlaybackService {
  bool _isInitialized = false;
  bool _isSupported = true;
  DateTime _playbackEndTime = DateTime.now();

  /// Vrací true, pokud se v reproduktoru ještě přehrává audio (s bezpečnostní rezervou pro doznění).
  bool get isPlaying {
    if (!_isInitialized || !_isSupported) return false;
    return DateTime.now().isBefore(_playbackEndTime.add(const Duration(milliseconds: 400)));
  }

  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;
  
  final List<_VolumeQueueItem> _volumeQueue = [];
  Timer? _volumeTimer;

  Future<void> init() async {
    if (!_isInitialized && _isSupported) {
      try {
        // Gemini Live API posílá zvuk v 24kHz PCM 16-bit Mono
        await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
        _isInitialized = true;
        
        // Spuštění timeru pro synchronizované vysílání hlasitosti do UI
        _volumeTimer?.cancel();
        _volumeTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
          _emitQueuedVolumes();
        });
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

    // Připočteme délku přehrávání: 24000 Hz 16-bit mono = 48 bytů za milisekundu
    final int durationMs = (safeBytes.length / 48.0).ceil();
    final now = DateTime.now();
    
    DateTime chunkStartTime;
    if (_playbackEndTime.isBefore(now)) {
      chunkStartTime = now;
      _playbackEndTime = now.add(Duration(milliseconds: durationMs));
    } else {
      chunkStartTime = _playbackEndTime;
      _playbackEndTime = _playbackEndTime.add(Duration(milliseconds: durationMs));
    }
    
    try {
      // Výpočet hlasitosti pro vizualizaci a přidání do časované fronty
      final volume = _calculateVolume(safeBytes);
      _volumeQueue.add(_VolumeQueueItem(chunkStartTime, volume));

      // Převod surových bytů na PcmArrayInt16
      final uint8List = Uint8List.fromList(safeBytes);
      final byteData = ByteData.sublistView(uint8List);
      final pcmArray = PcmArrayInt16(bytes: byteData);
      
      await FlutterPcmSound.feed(pcmArray);
    } catch (e) {
      debugPrint('Chyba při přehrávání audia: $e');
    }
  }

  double _calculateVolume(List<int> buffer) {
    if (buffer.isEmpty) return 0.0;

    final int sampleCount = buffer.length ~/ 2;
    if (sampleCount == 0) return 0.0;
    
    double sum = 0;
    final byteData = ByteData.sublistView(Uint8List.fromList(buffer));
    
    for (int i = 0; i < buffer.length - 1; i += 2) {
      final int sample = byteData.getInt16(i, Endian.little);
      sum += sample * sample;
    }
    
    final double rms = math.sqrt(sum / sampleCount);
    double volume = math.sqrt(rms / 32768.0);
    
    if (volume.isNaN) {
      volume = 0.0;
    }
    
    return volume.clamp(0.0, 1.0);
  }

  void _emitQueuedVolumes() {
    if (_volumeQueue.isEmpty) return;
    
    final now = DateTime.now();
    double? volumeToEmit;
    
    // Najdeme poslední hodnotu, jejíž čas už reálně nastal
    while (_volumeQueue.isNotEmpty && _volumeQueue.first.scheduledTime.isBefore(now)) {
      volumeToEmit = _volumeQueue.first.volume;
      _volumeQueue.removeAt(0);
    }
    
    if (volumeToEmit != null) {
      _volumeController.add(volumeToEmit);
    }
  }

  Future<void> interrupt() async {
    _playbackEndTime = DateTime.now();
    await stop();
  }

  Future<void> stop() async {
    _playbackEndTime = DateTime.now();
    _volumeQueue.clear();
    if (_isSupported && _isInitialized) {
      try {
        await FlutterPcmSound.release();
        _volumeController.add(0.0);
      } catch (_) {}
    }
    _isInitialized = false;
  }

  void dispose() {
    _volumeTimer?.cancel();
    _volumeController.close();
  }
}
