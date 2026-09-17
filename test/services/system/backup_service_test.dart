import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/system/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Directory testDir;

  setUp(() {
    BackupService.resetState();
    container = ProviderContainer();
    testDir = Directory.systemTemp.createTempSync('backup_service_test_');
  });

  tearDown(() {
    BackupService.resetState();
    container.dispose();
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('BackupService Header & File Validation Tests', () {
    test('isValidSqliteHeader accepts valid SQLite 3 header', () {
      final validHeader = 'SQLite format 3\u0000'.codeUnits;
      expect(BackupService.isValidSqliteHeader(validHeader), true);
    });

    test('isValidSqliteHeader rejects short or invalid header bytes', () {
      expect(BackupService.isValidSqliteHeader([]), false);
      expect(BackupService.isValidSqliteHeader('SQLite'.codeUnits), false);
      expect(BackupService.isValidSqliteHeader('NOT SQLITE FILE!'.codeUnits), false);
      expect(BackupService.isValidSqliteHeader('{"test": true}'.codeUnits), false);
    });

    test('validateSqliteFile correctly validates files on disk', () async {
      // 1. Non-existent file
      final nonExistent = File('${testDir.path}/non_existent.sqlite');
      expect(await BackupService.validateSqliteFile(nonExistent), false);

      // 2. Corrupted / text file
      final textFile = File('${testDir.path}/text_file.txt');
      await textFile.writeAsString('Hello world, not a database');
      expect(await BackupService.validateSqliteFile(textFile), false);

      // 3. Valid SQLite file
      final validDbFile = File('${testDir.path}/valid.sqlite');
      final headerBytes = 'SQLite format 3\u0000SomeOtherDataBytes'.codeUnits;
      await validDbFile.writeAsBytes(headerBytes);
      expect(await BackupService.validateSqliteFile(validDbFile), true);
    });
  });

  group('BackupService Export Tests', () {
    test('exportBackup returns false if database file does not exist', () async {
      final nonExistentDb = File('${testDir.path}/absent_db.sqlite');
      BackupService.dbFileOverride = nonExistentDb;

      final service = container.read(backupServiceProvider);
      final result = await service.exportBackup();
      expect(result, false);
    });

    test('exportBackup copies database to temporary backup file', () async {
      final mockDbFile = File('${testDir.path}/db.sqlite');
      await mockDbFile.writeAsString('SQLite format 3\u0000test_database_content');
      BackupService.dbFileOverride = mockDbFile;

      final tempDir = Directory('${testDir.path}/temp');
      await tempDir.create();
      BackupService.tempDirOverride = tempDir;

      final service = container.read(backupServiceProvider);

      // Note: SharePlus.instance.share will fail/return dismissed in headless unit tests,
      // but the file preparation logic (copying to tempBackupFile) should execute successfully.
      await service.exportBackup();

      final preparedTempFile = File('${tempDir.path}/aj_tudor_backup.sqlite');
      expect(preparedTempFile.existsSync(), true);
      expect(await preparedTempFile.readAsString(), 'SQLite format 3\u0000test_database_content');
    });
  });

  group('BackupService Provider Resolution Test', () {
    test('backupServiceProvider resolves BackupService instance', () {
      final service = container.read(backupServiceProvider);
      expect(service, isA<BackupService>());
    });
  });
}

