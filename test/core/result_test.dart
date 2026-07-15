import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/error/error_handling.dart';
import 'package:aj_tudor/core/utils/result.dart';

void main() {
  group('Result Tests', () {
    test('Success should return value and be isSuccess', () {
      const result = Result<int>.success(42);
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.getOrThrow(), 42);
    });

    test('Failure should return failure and be isFailure', () {
      const failure = ApiFailure('Error');
      final result = Result<int>.failure(failure);
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(() => result.getOrThrow(), throwsA(isA<ApiFailure>()));
    });

    test('fold should work correctly for success', () {
      const result = Result<String>.success('ok');
      final value = result.fold(
        (s) => s.toUpperCase(),
        (f) => 'fail',
      );
      expect(value, 'OK');
    });

    test('fold should work correctly for failure', () {
      const result = Result<String>.failure(ApiFailure('bad'));
      final value = result.fold(
        (s) => s,
        (f) => 'fail',
      );
      expect(value, 'fail');
    });
  });
}
