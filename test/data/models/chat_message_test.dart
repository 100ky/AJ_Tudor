import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/models/chat_message.dart';

void main() {
  group('ChatMessage & Smart Bubbles Model Tests', () {
    test('ChatMessage without corrections should have hasCorrections = false', () {
      final msg = ChatMessage('Hello world', isUser: true);
      expect(msg.hasCorrections, false);
      expect(msg.corrections, null);
    });

    test('ChatMessage with corrections should report hasCorrections = true', () {
      const correction = ChatMessageCorrection(
        userSaid: 'I go yesterday',
        correctForm: 'I went yesterday',
        explanation: 'Minulý čas od slovesa go je went.',
        errorType: 'grammar',
      );

      final msg = ChatMessage(
        'I go yesterday',
        isUser: true,
        corrections: const [correction],
        correctedSentence: 'I went yesterday',
      );

      expect(msg.hasCorrections, true);
      expect(msg.corrections?.length, 1);
      expect(msg.corrections?.first.correctForm, 'I went yesterday');
      expect(msg.correctedSentence, 'I went yesterday');
    });
  });
}
