import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/utils/logger.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aj_tudor_log_test');
  });

  tearDown(() async {
    await L.stopFileLog();
    await tempDir.delete(recursive: true);
  });

  File sessionLog(int id) => File('${tempDir.path}/logs/sessions/session_$id.log');

  test('session log keeps the lesson lines and leaves out per-chunk noise', () async {
    await L.startFileLog(tempDir);
    L.i('Before the lesson');

    await L.startSessionLog(7);
    L.i('Tutor řekl: "Hello"');
    L.d('WebSocket KEYS: []');
    L.d('serverContent sub-keys: [modelTurn]');
    L.d('serverContent sub-keys: [turnComplete]');
    await L.endSessionLog(7);

    L.i('After the lesson');
    await L.stopFileLog();

    final content = await sessionLog(7).readAsString();
    expect(content, contains('=== Lekce #7'));
    expect(content, contains('Tutor řekl: "Hello"'));
    expect(content, contains('sub-keys: [turnComplete]'));
    expect(content, isNot(contains('WebSocket KEYS: []')));
    expect(content, isNot(contains('sub-keys: [modelTurn]')));
    expect(content, isNot(contains('Before the lesson')));
    expect(content, isNot(contains('After the lesson')));
  });

  test('ending another lesson does not close the log being written', () async {
    await L.startFileLog(tempDir);
    await L.startSessionLog(8);
    await L.endSessionLog(5);
    L.i('Still lesson 8');
    await L.stopFileLog();

    expect(await sessionLog(8).readAsString(), contains('Still lesson 8'));
  });

  test('app start keeps only the newest session logs', () async {
    final dir = Directory('${tempDir.path}/logs/sessions');
    await dir.create(recursive: true);
    for (var id = 1; id <= L.keptSessionLogs + 2; id++) {
      await File('${dir.path}/session_$id.log').writeAsString('lesson $id');
    }

    await L.startFileLog(tempDir);

    expect(await sessionLog(1).exists(), isFalse);
    expect(await sessionLog(2).exists(), isFalse);
    expect(await sessionLog(3).exists(), isTrue);
    expect(await sessionLog(L.keptSessionLogs + 2).exists(), isTrue);
  });

  test('without file logging there is no session log', () async {
    await L.startSessionLog(9);
    L.i('Nowhere');
    await L.endSessionLog(9);

    expect(await sessionLog(9).exists(), isFalse);
  });
}
