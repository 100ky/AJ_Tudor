import 'dart:async';

import 'package:aj_tudor/features/flashcards/answer_recorder.dart';
import 'package:aj_tudor/services/audio/audio_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCapture extends Mock implements AudioCaptureService {}

void main() {
  late _MockCapture capture;
  late StreamController<List<int>> audio;
  late StreamController<double> volume;

  setUp(() {
    capture = _MockCapture();
    audio = StreamController<List<int>>.broadcast();
    volume = StreamController<double>.broadcast();
    when(() => capture.audioStream).thenAnswer((_) => audio.stream);
    when(() => capture.volumeStream).thenAnswer((_) => volume.stream);
    when(() => capture.startRecording()).thenAnswer((_) async {});
    when(() => capture.stopRecording()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await audio.close();
    await volume.close();
  });

  Future<AnswerRecorder> record({required int bytes, required double loudest}) async {
    final recorder = AnswerRecorder(capture);
    await recorder.start(onVolume: (_) {});
    audio.add(List<int>.filled(bytes, 0));
    volume.add(0.03);
    volume.add(loudest);
    await Future<void>.delayed(Duration.zero);
    await recorder.stop();
    return recorder;
  }

  test('a double tap records too little to be evaluated', () async {
    // Kartičky 8. 11.: dvojí rychlé klepnutí na mikrofon se uznalo jako správná odpověď
    final recorder = await record(bytes: 6400, loudest: 0.3);
    expect(recorder.isTooShort, isTrue);
  });

  test('a recording of room noise has no speech, a spoken answer has', () async {
    expect((await record(bytes: 32000, loudest: 0.05)).heardSpeech, isFalse);
    final spoken = await record(bytes: 32000, loudest: 0.3);
    expect(spoken.isTooShort, isFalse);
    expect(spoken.heardSpeech, isTrue);
  });
}
