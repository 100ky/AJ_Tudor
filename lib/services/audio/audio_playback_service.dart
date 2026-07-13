import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioPlaybackService {
  bool _isInitialized = false;

  Future<void> init() async {
    if (!_isInitialized) {
      // Gemini Live API posílá zvuk v 24kHz PCM 16-bit Mono
      await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
      _isInitialized = true;
    }
  }

  Future<void> playPcmData(List<int> pcmBytes) async {
    if (!_isInitialized) await init();
    
    // Převod surových bytů na PcmArrayInt16
    final uint8List = Uint8List.fromList(pcmBytes);
    final byteData = ByteData.sublistView(uint8List);
    final pcmArray = PcmArrayInt16(bytes: byteData);
    
    await FlutterPcmSound.feed(pcmArray);
  }

  Future<void> stop() async {
    await FlutterPcmSound.release();
    _isInitialized = false;
  }
}
