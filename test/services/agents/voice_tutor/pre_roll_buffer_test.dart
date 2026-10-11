import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/pre_roll_buffer.dart';

void main() {
  group('PreRollBuffer', () {
    test('keeps only the newest audio within the byte limit', () {
      final buffer = PreRollBuffer(maxBytes: 10);
      buffer.add([1, 1, 1, 1]);
      buffer.add([2, 2, 2, 2]);
      buffer.add([3, 3, 3, 3]);

      expect(buffer.drain(), [
        [2, 2, 2, 2],
        [3, 3, 3, 3],
      ]);
    });

    test('a single block larger than the limit is still kept', () {
      final buffer = PreRollBuffer(maxBytes: 2);
      buffer.add([1, 2, 3, 4]);

      expect(buffer.drain(), [
        [1, 2, 3, 4],
      ]);
    });

    test('drain empties the buffer', () {
      final buffer = PreRollBuffer();
      buffer.add([1, 2]);
      buffer.drain();

      expect(buffer.drain(), isEmpty);
    });
  });
}
