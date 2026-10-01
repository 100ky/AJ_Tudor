import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/speech_activity_detector.dart';

/// PCM 16-bit LE blok s konstantní amplitudou.
List<int> pcmBlock(int amplitude, {int samples = 160}) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('pcm16Volume', () {
    test('silence is 0 and full scale is ~1', () {
      expect(pcm16Volume(pcmBlock(0)), 0.0);
      expect(pcm16Volume(pcmBlock(32767)), closeTo(1.0, 0.001));
    });

    test('uses the square root of RMS to boost quiet speech', () {
      // RMS 8192 = 1/4 full scale → sqrt(0.25) = 0.5
      expect(pcm16Volume(pcmBlock(8192)), closeTo(0.5, 0.001));
    });

    test('a buffer shorter than one sample has no volume', () {
      expect(pcm16Volume(const [1]), 0.0);
    });
  });

  group('SpeechActivityDetector', () {
    late SpeechActivityDetector vad;

    setUp(() => vad = SpeechActivityDetector());

    test('starts with the default noise floor and minimum thresholds', () {
      expect(vad.noiseFloor, SpeechActivityDetector.initialNoiseFloor);
      expect(vad.startThreshold, closeTo(0.072, 1e-9));
      expect(vad.holdThreshold, closeTo(0.058, 1e-9));
    });

    test('classifies speech, silence and sustain with hysteresis', () {
      expect(vad.classify(0.10, adaptNoiseFloor: false), VoiceLevel.speech);
      expect(vad.classify(0.065, adaptNoiseFloor: false), VoiceLevel.sustain);
      expect(vad.classify(0.03, adaptNoiseFloor: false), VoiceLevel.silence);
    });

    test('learns the noise floor only when allowed and only from quiet blocks', () {
      vad.classify(0.06, adaptNoiseFloor: false);
      expect(vad.noiseFloor, SpeechActivityDetector.initialNoiseFloor);

      vad.classify(0.20, adaptNoiseFloor: true); // too loud to be noise
      expect(vad.noiseFloor, SpeechActivityDetector.initialNoiseFloor);

      vad.classify(0.06, adaptNoiseFloor: true);
      expect(vad.noiseFloor, closeTo(0.050 * 0.95 + 0.06 * 0.05, 1e-9));
    });

    test('a noisy room raises both thresholds', () {
      for (var i = 0; i < 200; i++) {
        vad.classify(0.064, adaptNoiseFloor: true);
      }
      expect(vad.noiseFloor, closeTo(0.064, 0.001));
      expect(vad.startThreshold, closeTo(0.084, 0.001));
      expect(vad.holdThreshold, closeTo(0.072, 0.001));
    });

    test('speech needs two consecutive chunks', () {
      expect(vad.countSpeechChunk(), false);
      expect(vad.countSpeechChunk(), true);

      vad.resetSpeechChunks();
      expect(vad.countSpeechChunk(), false);

      vad.markSpeechChunk();
      expect(vad.countSpeechChunk(), true);
    });

    test('reset restores the initial state', () {
      vad.classify(0.06, adaptNoiseFloor: true);
      vad.countSpeechChunk();
      vad.reset();
      expect(vad.noiseFloor, SpeechActivityDetector.initialNoiseFloor);
      expect(vad.countSpeechChunk(), false);
    });
  });
}
