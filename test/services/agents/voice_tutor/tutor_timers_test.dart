import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/voice_tutor/tutor_timers.dart';

void main() {
  group('TutorTimers', () {
    late TutorTimers timers;

    setUp(() => timers = TutorTimers());
    tearDown(() => timers.cancelAll());

    test('a started timer fires once and is no longer active', () async {
      var fired = 0;
      timers.start(TutorTimer.thinking, const Duration(milliseconds: 10), () => fired++);
      expect(timers.isActive(TutorTimer.thinking), true);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fired, 1);
      expect(timers.isActive(TutorTimer.thinking), false);
    });

    test('restarting replaces the previous timer of the same kind', () async {
      final fired = <String>[];
      timers.start(TutorTimer.watchdog, const Duration(milliseconds: 10), () => fired.add('first'));
      timers.start(TutorTimer.watchdog, const Duration(milliseconds: 10), () => fired.add('second'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fired, ['second']);
    });

    test('cancel stops only the given timer', () async {
      final fired = <TutorTimer>[];
      timers.start(TutorTimer.stuck, const Duration(milliseconds: 10), () => fired.add(TutorTimer.stuck));
      timers.start(TutorTimer.vadSilence, const Duration(milliseconds: 10),
          () => fired.add(TutorTimer.vadSilence));

      timers.cancel(TutorTimer.stuck);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fired, [TutorTimer.vadSilence]);
    });

    test('cancelAll stops every running timer', () async {
      var fired = 0;
      for (final kind in TutorTimer.values) {
        timers.start(kind, const Duration(milliseconds: 10), () => fired++);
      }

      timers.cancelAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fired, 0);
      expect(TutorTimer.values.any(timers.isActive), false);
    });
  });
}
