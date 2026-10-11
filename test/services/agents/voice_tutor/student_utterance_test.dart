import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/student_utterance.dart';

void main() {
  group('StudentUtterance', () {
    test('the corrected transcript wins over the live one once it is done', () {
      final utterance = StudentUtterance(sessionId: 1)..liveText = '¿Qué?';
      expect(utterance.finalText, '¿Qué?');

      utterance
        ..correctedText = 'Cože?'
        ..correctionDone = true;
      expect(utterance.finalText, 'Cože?');
    });

    test('a failed correction falls back to the live transcript', () {
      final failed = StudentUtterance(sessionId: 1)
        ..liveText = 'I need practice.'
        ..correctionDone = true;

      expect(failed.finalText, 'I need practice.');
    });

    test('no speech in the recording drops a short live guess but keeps a longer one', () {
      final noise = StudentUtterance(sessionId: 1)
        ..liveText = '¿Qué?'
        ..correctedText = ''
        ..correctionDone = true;
      final missed = StudentUtterance(sessionId: 1)
        ..liveText = 'I need more practice.'
        ..correctedText = ''
        ..correctionDone = true;

      expect(noise.finalText, '');
      expect(missed.finalText, 'I need more practice.');
    });

    test('is ready to save only with both transcripts and only once', () {
      final utterance = StudentUtterance(sessionId: 1);
      expect(utterance.readyToSave, isFalse);

      utterance.correctionDone = true;
      expect(utterance.readyToSave, isFalse);

      utterance.liveDone = true;
      expect(utterance.readyToSave, isTrue);

      utterance.saved = true;
      expect(utterance.readyToSave, isFalse);
    });

    test('reopening keeps the audio and invalidates the running correction', () {
      final utterance = StudentUtterance(sessionId: 1)..addAudio([1, 2]);
      final round = utterance.beginCorrection();
      utterance
        ..correctedText = 'old'
        ..correctionDone = true;

      utterance.reopen();
      utterance.addAudio([3, 4]);

      expect(utterance.isCurrentRound(round), isFalse);
      expect(utterance.correctionDone, isFalse);
      expect(utterance.correctedText, isNull);
      expect(utterance.audioBytes(), [1, 2, 3, 4]);
    });

    test('audio over two minutes is not sent for correction', () {
      final utterance = StudentUtterance(sessionId: 1)
        ..addAudio(List<int>.filled(StudentUtterance.maxAudioBytes, 0))
        ..addAudio([1]);

      expect(utterance.audioBytes(), isEmpty);
    });
  });
}
