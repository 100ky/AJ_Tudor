import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/gemini/pronunciation_service.dart';

void main() {
  group('PronunciationService & Audio Conversion Tests', () {
    late ProviderContainer container;
    late PronunciationService service;

    setUp(() {
      container = ProviderContainer();
      service = container.read(pronunciationServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('pcm16ToWav generates valid standard 44-byte RIFF/WAV header', () {
      // 100 vzorků ticha (200 bytů)
      final dummyPcm = List<int>.filled(200, 0);
      final wavBytes = service.pcm16ToWav(dummyPcm, sampleRate: 16000, channels: 1);

      expect(wavBytes.length, 244); // 44 byte header + 200 byte PCM

      // RIFF magic 'RIFF'
      expect(wavBytes[0], 0x52); // R
      expect(wavBytes[1], 0x49); // I
      expect(wavBytes[2], 0x46); // F
      expect(wavBytes[3], 0x46); // F

      // WAVE magic 'WAVE'
      expect(wavBytes[8], 0x57);  // W
      expect(wavBytes[9], 0x41);  // A
      expect(wavBytes[10], 0x56); // V
      expect(wavBytes[11], 0x45); // E

      // fmt subchunk 'fmt '
      expect(wavBytes[12], 0x66); // f
      expect(wavBytes[13], 0x6D); // m
      expect(wavBytes[14], 0x74); // t
      expect(wavBytes[15], 0x20); // ' '

      // AudioFormat = 1 (PCM)
      final byteData = ByteData.sublistView(wavBytes);
      expect(byteData.getUint16(20, Endian.little), 1);

      // Channels = 1
      expect(byteData.getUint16(22, Endian.little), 1);

      // SampleRate = 16000
      expect(byteData.getUint32(24, Endian.little), 16000);

      // BitsPerSample = 16
      expect(byteData.getUint16(34, Endian.little), 16);

      // data subchunk size = 200
      expect(byteData.getUint32(40, Endian.little), 200);
    });

    test('WordPronunciationResult correctly reflects accurate and mispronounced words', () {
      const correctWord = WordPronunciationResult(
        expectedWord: 'London',
        recognizedWord: 'London',
        isAccurate: true,
        confidence: 0.96,
      );

      const mispronouncedWord = WordPronunciationResult(
        expectedWord: 'the',
        recognizedWord: 'de',
        isAccurate: false,
        confidence: 0.62,
        phoneticTip: 'Dej si pozor na znělé th (/ð/)',
      );

      expect(correctWord.isAccurate, true);
      expect(mispronouncedWord.isAccurate, false);
      expect(mispronouncedWord.phoneticTip, contains('/ð/'));
    });

    test('PronunciationService preferredWorkingModel can be read and reset', () {
      PronunciationService.resetState();
      expect(PronunciationService.preferredWorkingModel, isNull);
    });
  });
}
