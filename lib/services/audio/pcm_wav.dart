import 'dart:typed_data';

/// Zda [bytes] začínají hlavičkou WAV souboru (RIFF … WAVE).
bool isWav(List<int> bytes) =>
    bytes.length >= 12 &&
    String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
    String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';

/// Vytáhne z WAV souboru surová PCM data (blok `data`) a jejich vzorkovací frekvenci.
///
/// Ostatní bloky (např. metadata C2PA za zvukem) vynechá. Vrátí null, když [bytes]
/// nejsou WAV nebo v nich blok `data` chybí.
({Uint8List pcm, int sampleRate})? pcm16FromWav(List<int> bytes) {
  if (!isWav(bytes)) return null;
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);
  var sampleRate = 24000;
  var offset = 12;
  while (offset + 8 <= data.length) {
    final id = String.fromCharCodes(data.sublist(offset, offset + 4));
    final size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ' && body + 8 <= data.length) {
      sampleRate = view.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      final end = (body + size).clamp(body, data.length);
      return (pcm: Uint8List.sublistView(data, body, end), sampleRate: sampleRate);
    }
    offset = body + size + (size & 1); // bloky jsou zarovnané na sudý počet bajtů
  }
  return null;
}

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
