import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioPlaybackService {
  bool _isInitialized = false;
  bool _isSupported = true;

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
    
    try {
      // Převod surových bytů na PcmArrayInt16
      final uint8List = Uint8List.fromList(pcmBytes);
      final byteData = ByteData.sublistView(uint8List);
      final pcmArray = PcmArrayInt16(bytes: byteData);
      
      await FlutterPcmSound.feed(pcmArray);
    } catch (e) {
      debugPrint('Chyba při přehrávání audia: $e');
    }
  }

  Future<void> stop() async {
    if (_isSupported && _isInitialized) {
      try {
        await FlutterPcmSound.release();
      } catch (_) {}
    }
    _isInitialized = false;
  }
}
