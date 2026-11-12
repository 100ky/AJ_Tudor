import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
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

  group('BackupService restore', () {
    late File dbFile;

    /// Vytvoří databázi s jednou lekcí na téma [topic]; bez [appTables] databázi jiné aplikace.
    File createDatabase(String name, String topic, {bool appTables = true}) {
      final file = File('${testDir.path}/$name');
      final database = sqlite3.open(file.path);
      try {
        if (appTables) {
          database.execute('CREATE TABLE sessions (id INTEGER PRIMARY KEY, topic TEXT)');
          database.execute('CREATE TABLE transcripts (id INTEGER PRIMARY KEY, content TEXT)');
          database.execute('INSERT INTO sessions (topic) VALUES (?)', [topic]);
        } else {
          database.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');
          database.execute('INSERT INTO notes (body) VALUES (?)', [topic]);
        }
      } finally {
        database.close();
      }
      return file;
    }

    String topicIn(File file) {
      final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return database.select('SELECT topic FROM sessions').single['topic'] as String;
      } finally {
        database.close();
      }
    }

    setUp(() {
      dbFile = createDatabase('db.sqlite', 'old lesson');
      BackupService.dbFileOverride = dbFile;
    });

    test('restore replaces the data and keeps the previous database next to it', () async {
      final backup = createDatabase('backup.sqlite', 'lesson from the backup');

      final restored = await container.read(backupServiceProvider).restoreFrom(backup);

      expect(restored, isTrue);
      expect(topicIn(dbFile), 'lesson from the backup');
      expect(topicIn(File('${dbFile.path}.bak')), 'old lesson');
      expect(File('${dbFile.path}.import').existsSync(), isFalse);
      // Soubor zálohy se nemění
      expect(topicIn(backup), 'lesson from the backup');
    });

    test('a connection that stays open during the restore reads the restored data', () async {
      // Obrazovky si databázi po zavření hned otevřou znovu. Dřív se soubor smazal
      // a nahradil pod otevřeným spojením, které pak dál četlo i zapisovalo do smazaného.
      final live = sqlite3.open(dbFile.path);
      try {
        expect(live.select('SELECT topic FROM sessions').single['topic'], 'old lesson');
        final backup = createDatabase('backup.sqlite', 'lesson from the backup');

        expect(await container.read(backupServiceProvider).restoreFrom(backup), isTrue);

        expect(live.select('SELECT topic FROM sessions').single['topic'], 'lesson from the backup');
      } finally {
        live.close();
      }
    });

    test('a damaged file with an SQLite header is refused and the data stay as they were', () async {
      final damaged = File('${testDir.path}/damaged.sqlite');
      await damaged.writeAsBytes([...'SQLite format 3\u0000'.codeUnits, ...List.filled(8192, 7)]);
      // Hlavička sedí, takže dřívější kontrola by soubor pustila dál
      expect(await BackupService.validateSqliteFile(damaged), isTrue);

      final restored = await container.read(backupServiceProvider).restoreFrom(damaged);

      expect(restored, isFalse);
      expect(topicIn(dbFile), 'old lesson');
      expect(File('${dbFile.path}.bak').existsSync(), isFalse);
      expect(File('${dbFile.path}.import').existsSync(), isFalse);
    });

    test('a database of another app is refused', () async {
      final foreign = createDatabase('foreign.sqlite', 'shopping list', appTables: false);

      expect(BackupService.checkBackupDatabase(foreign), contains('chybí tabulky sessions, transcripts'));
      expect(await container.read(backupServiceProvider).restoreFrom(foreign), isFalse);
      expect(topicIn(dbFile), 'old lesson');
    });

    test('a file that is not SQLite at all is refused', () async {
      final text = File('${testDir.path}/notes.txt');
      await text.writeAsString('Hello world, not a database');

      expect(await container.read(backupServiceProvider).restoreFrom(text), isFalse);
      expect(topicIn(dbFile), 'old lesson');
    });

    test('a valid backup passes the check', () {
      expect(BackupService.checkBackupDatabase(createDatabase('backup.sqlite', 'lesson')), isNull);
    });
  });

  group('BackupService Provider Resolution Test', () {
    test('backupServiceProvider resolves BackupService instance', () {
      final service = container.read(backupServiceProvider);
      expect(service, isA<BackupService>());
    });
  });
}

