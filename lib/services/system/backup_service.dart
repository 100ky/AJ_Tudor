import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../core/utils/logger.dart';
import '../../data/data_providers.dart';

/// Služba pro provádění exportu a importu zálohy databáze SQLite.
class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  @visibleForTesting
  static File? dbFileOverride;

  @visibleForTesting
  static Directory? tempDirOverride;

  @visibleForTesting
  static void resetState() {
    dbFileOverride = null;
    tempDirOverride = null;
  }

  /// Ověří, zda pole bajtů obsahuje platnou hlavičku SQLite databáze (prvních 16 bajtů).
  static bool isValidSqliteHeader(List<int> bytes) {
    if (bytes.length < 16) return false;
    final header = String.fromCharCodes(bytes.take(16));
    return header.startsWith('SQLite format 3');
  }

  /// Ověří, zda je soubor existující a platnou SQLite databází.
  static Future<bool> validateSqliteFile(File file) async {
    if (!await file.exists()) return false;
    try {
      final bytes = await file.openRead(0, 16).first;
      return isValidSqliteHeader(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Získá cestu k databázovému souboru aplikace.
  Future<File> _getDatabaseFile() async {
    if (dbFileOverride != null) return dbFileOverride!;
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'db.sqlite'));
  }

  /// Exportuje databázi (pokrok) pomocí systémového sdílení (share sheet).
  /// Uživatel může soubor uložit na Google Drive, iCloud, poslat na email, atd.
  Future<bool> exportBackup() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) {
        L.w('Pokus o export neexistující databáze.');
        return false;
      }

      // Pro jistotu zkopírujeme databázi do dočasného souboru, abychom neblokovali ostrý soubor
      final tempDir = tempDirOverride ?? await getTemporaryDirectory();
      final tempBackupFile = File(p.join(tempDir.path, 'aj_tudor_backup.sqlite'));

      // Pokud starý dočasný soubor existuje, smažeme ho
      if (await tempBackupFile.exists()) {
        await tempBackupFile.delete();
      }

      await dbFile.copy(tempBackupFile.path);
      L.i('Záloha databáze připravena v dočasném souboru: ${tempBackupFile.path}');

      // Sdílení souboru pomocí share_plus (v12 API)
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempBackupFile.path, mimeType: 'application/x-sqlite3')],
          subject: 'AJ Tudor - Záloha pokroku',
        ),
      );

      L.i('Sdílení dokončeno s výsledkem: ${result.status}');
      // Většina platforem považuje sdílení za úspěšné, pokud nevznikla výjimka. 
      // Status 'dismissed' může nastat i při uložení do souborů na iOS.
      return result.status == ShareResultStatus.success || 
             result.status == ShareResultStatus.dismissed ||
             result.status == ShareResultStatus.unavailable;
    } catch (e, stack) {
      L.e('Chyba při exportu zálohy', e, stack);
      return false;
    }
  }

  /// Importuje databázi ze souboru, který student vybere.
  Future<bool> importBackup() async {
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (pickedFile == null || pickedFile.path == null) {
        L.i('Uživatel stornoval výběr souboru pro obnovu.');
        return false;
      }

      return await restoreFrom(File(pickedFile.path!));
    } catch (e, stack) {
      L.e('Chyba při importu zálohy', e, stack);
      return false;
    }
  }

  /// Tabulky, které musí záloha obsahovat, aby šlo o databázi této aplikace.
  static const List<String> requiredBackupTables = ['sessions', 'transcripts'];

  /// Jak dlouho smí kopírování databáze čekat, až ji uvolní jiné spojení.
  static const Duration copyTimeout = Duration(seconds: 15);

  /// Nahradí data aplikace zálohou [backupFile]. Vrátí, zda se obnova povedla.
  ///
  /// Záloha se nejdřív zkopíruje vedle databáze a ověří: soubor musí být celistvý
  /// a obsahovat tabulky aplikace. Původní data se uloží do `db.sqlite.bak`. Obsah zálohy
  /// se pak do databáze zapíše zálohovacím API SQLite v jedné transakci, takže databáze
  /// má buď celý obsah zálohy, nebo zůstane beze změny.
  ///
  /// Dřív se soubor databáze smazal a záloha se zkopírovala na jeho místo. Ověřovala se
  /// jen hlavička souboru, takže poškozená záloha nebo přerušené kopírování znamenaly
  /// ztrátu dat. Databázi navíc mezitím znovu otevřely obrazovky a zapisovaly dál
  /// do smazaného souboru.
  Future<bool> restoreFrom(File backupFile) async {
    if (!await validateSqliteFile(backupFile)) {
      L.w('Vybraný soubor není platná SQLite databáze.');
      return false;
    }

    final dbFile = await _getDatabaseFile();
    final incoming = File('${dbFile.path}.import');
    try {
      await _deleteDatabaseFile(incoming);
      await backupFile.copy(incoming.path);

      final problem = checkBackupDatabase(incoming);
      if (problem != null) {
        L.w('Záloha se neobnoví: $problem');
        return false;
      }

      if (await dbFile.exists()) {
        final previous = File('${dbFile.path}.bak');
        await _deleteDatabaseFile(previous);
        await _copyDatabase(from: dbFile, to: previous);
        L.i('Původní data zůstávají v ${previous.path}.');
      }

      L.i('Začíná obnova ze zálohy: ${backupFile.path}');
      await _copyDatabase(from: incoming, to: dbFile);
      L.i('Databáze má obsah zálohy.');

      // Nové spojení: při otevření proběhnou opravy schématu (záloha může být ze starší
      // verze aplikace) a obrazovky si načtou nová data
      _ref.invalidate(databaseProvider);
      return true;
    } catch (e, stack) {
      L.e('Chyba při obnově ze zálohy', e, stack);
      return false;
    } finally {
      try {
        await _deleteDatabaseFile(incoming);
      } catch (e) {
        L.w('Dočasnou kopii zálohy se nepodařilo smazat: $e');
      }
    }
  }

  /// Ověří, že [file] je celistvá databáze této aplikace. Vrátí null, nebo popis problému.
  static String? checkBackupDatabase(File file) {
    Database? database;
    try {
      database = sqlite3.open(file.path, mode: OpenMode.readWrite);
      final integrity = database.select('PRAGMA integrity_check');
      final verdict = integrity.isEmpty ? '' : integrity.first.values.first?.toString() ?? '';
      if (verdict != 'ok') return 'soubor je poškozený ($verdict)';

      final tables = {
        for (final row in database.select("SELECT name FROM sqlite_master WHERE type = 'table'"))
          row['name'] as String,
      };
      final missing = [for (final table in requiredBackupTables) if (!tables.contains(table)) table];
      if (missing.isNotEmpty) return 'není to záloha AJ Tudora (chybí tabulky ${missing.join(', ')})';
      return null;
    } on SqliteException catch (e) {
      return 'soubor nejde přečíst jako databázi (${e.message})';
    } finally {
      database?.close();
    }
  }

  /// Zkopíruje obsah databáze [from] do [to] zálohovacím API SQLite.
  ///
  /// Kopíruje se najednou v jedné transakci nad cílem, takže ostatní spojení vidí cíl
  /// buď celý původní, nebo celý nový. Soubor cíle se nemaže ani nepřejmenovává, otevřená
  /// spojení k němu proto zůstanou platná. Když cíl právě používá jiné spojení, kopírování
  /// to zkouší znovu, nejdéle [copyTimeout].
  static Future<void> _copyDatabase({required File from, required File to}) async {
    final source = sqlite3.open(from.path, mode: OpenMode.readWrite);
    try {
      final target = sqlite3.open(to.path);
      try {
        await source.backup(target, nPage: -1).drain<void>().timeout(copyTimeout);
      } finally {
        target.close();
      }
    } finally {
      source.close();
    }
  }

  /// Smaže soubor databáze i s pomocnými soubory SQLite, pokud existují.
  static Future<void> _deleteDatabaseFile(File file) async {
    for (final suffix in const ['', '-journal', '-wal', '-shm']) {
      final part = File('${file.path}$suffix');
      if (await part.exists()) await part.delete();
    }
  }
}

/// Provider poskytující instanci [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
