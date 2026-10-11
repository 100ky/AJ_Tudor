import 'dart:typed_data';

/// Převede surová PCM 16-bit Mono data na standardní WAV soubor s 44-bytovou hlavičkou.
Uint8List pcm16ToWav(List<int> pcmBytes, {int sampleRate = 16000, int channels = 1}) {
  final byteRate = sampleRate * channels * 2;
  final blockAlign = channels * 2;
  final subChunk2Size = pcmBytes.length;
  final chunkSize = 36 + subChunk2Size;

  final header = ByteData(44);
  // RIFF chunk descriptor
  header.setUint8(0, 0x52); // 'R'
  header.setUint8(1, 0x49); // 'I'
  header.setUint8(2, 0x46); // 'F'
  header.setUint8(3, 0x46); // 'F'
  header.setUint32(4, chunkSize, Endian.little);
  header.setUint8(8, 0x57); // 'W'
  header.setUint8(9, 0x41); // 'A'
  header.setUint8(10, 0x56); // 'V'
  header.setUint8(11, 0x45); // 'E'
  // fmt sub-chunk
  header.setUint8(12, 0x66); // 'f'
  header.setUint8(13, 0x6D); // 'm'
  header.setUint8(14, 0x74); // 't'
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
  header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
  header.setUint16(22, channels, Endian.little); // NumChannels
  header.setUint32(24, sampleRate, Endian.little); // SampleRate
  header.setUint32(28, byteRate, Endian.little); // ByteRate
  header.setUint16(32, blockAlign, Endian.little); // BlockAlign
  header.setUint16(34, 16, Endian.little); // BitsPerSample
  // data sub-chunk
  header.setUint8(36, 0x64); // 'd'
  header.setUint8(37, 0x61); // 'a'
  header.setUint8(38, 0x74); // 't'
  header.setUint8(39, 0x61); // 'a'
  header.setUint32(40, subChunk2Size, Endian.little);

  final wavBytes = Uint8List(44 + subChunk2Size);
  wavBytes.setRange(0, 44, header.buffer.asUint8List());
  wavBytes.setRange(44, 44 + subChunk2Size, pcmBytes);
  return wavBytes;
}
