import 'dart:math' as math;
import 'dart:typed_data';

/// Hlasitost bloku PCM 16-bit little-endian, normalizovaná do 0.0–1.0.
///
/// Používá odmocninu z RMS, aby byla citlivější na tichou řeč.
double pcm16Volume(List<int> buffer) {
  if (buffer.length < 2) return 0.0;

  double sum = 0;
  final int sampleCount = buffer.length ~/ 2;
  final byteData = ByteData.sublistView(Uint8List.fromList(buffer));

  for (int i = 0; i < buffer.length - 1; i += 2) {
    final int sample = byteData.getInt16(i, Endian.little);
    sum += sample * sample;
  }

  final double rms = math.sqrt(sum / sampleCount);
  return math.sqrt(rms / 32768.0);
}

/// Úroveň zvuku vůči prahům detektoru řeči.
enum VoiceLevel {
  /// Zřetelná řeč (nad startovním prahem).
  speech,

  /// Ticho (pod prahem pro udržení řeči).
  silence,

  /// Doznívání řeči mezi oběma prahy.
  sustain,
}

/// Lokální detekce hlasové aktivity (VAD) s adaptivním prahem šumu.
///
/// Prahy tvoří Schmittův klopný obvod (hysterezi): pro zahájení řeči je potřeba
/// vyšší hlasitost než pro její udržení, takže měkké souhlásky a doznívání
/// nepřerušují detekovanou řeč.
class SpeechActivityDetector {
  static const double initialNoiseFloor = 0.050;

  double _noiseFloor = initialNoiseFloor;
  int _consecutiveSpeechChunks = 0;

  /// Aktuální odhad okolního šumu.
  double get noiseFloor => _noiseFloor;

  /// Hlasitost nutná pro zahájení řeči (min. 0.072, s odstupem od šumu).
  double get startThreshold => math.max(0.072, _noiseFloor + 0.020);

  /// Hlasitost nutná pro udržení již detekované řeči.
  double get holdThreshold => math.max(0.058, _noiseFloor + 0.008);

  /// Zařadí hlasitost dalšího bloku.
  ///
  /// S [adaptNoiseFloor] se tichý blok (pod 0.065) započítá do odhadu šumu;
  /// volající to povolí jen při poslechu, když student nemluví, aby jeho hlas
  /// neposouval práh nahoru.
  VoiceLevel classify(double volume, {required bool adaptNoiseFloor}) {
    if (adaptNoiseFloor && volume < 0.065) {
      _noiseFloor = _noiseFloor * 0.95 + volume * 0.05;
    }
    if (volume >= startThreshold) return VoiceLevel.speech;
    if (volume < holdThreshold) return VoiceLevel.silence;
    return VoiceLevel.sustain;
  }

  /// Započítá blok řeči; vrátí true, jakmile jde o souvislou řeč (aspoň 2 bloky po sobě).
  bool countSpeechChunk() => ++_consecutiveSpeechChunks >= 2;

  /// Řeč už je zjištěná jedním blokem (např. student přerušil přemýšlení tutora).
  void markSpeechChunk() => _consecutiveSpeechChunks = 1;

  /// Ticho přerušilo souvislou řeč.
  void resetSpeechChunks() => _consecutiveSpeechChunks = 0;

  /// Výchozí stav pro novou lekci.
  void reset() {
    _noiseFloor = initialNoiseFloor;
    _consecutiveSpeechChunks = 0;
  }
}
