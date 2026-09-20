import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/logger.dart';
import '../../providers/database_provider.dart';

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

  /// Importuje databázi z vybraného souboru SQLite.
  /// Uzavře aktuální spojení, přepíše soubor databáze a obnoví stav providerů.
  Future<bool> importBackup() async {
    try {
      // 1. Výběr souboru od uživatele (v12 API)
      final pickedFile = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (pickedFile == null || pickedFile.path == null) {
        L.i('Uživatel stornoval výběr souboru pro obnovu.');
        return false;
      }

      final backupFilePath = pickedFile.path!;
      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        L.w('Vybraný soubor neexistuje.');
        return false;
      }

      // Validace, že vybraný soubor je platná SQLite databáze
      final isValid = await validateSqliteFile(backupFile);
      if (!isValid) {
        L.w('Vybraný soubor není platná SQLite databáze.');
        return false;
      }

      L.i('Začíná proces obnovy z: $backupFilePath');

      // 2. Uzavření databáze v aplikaci
      // Invalidace databaseProvideru způsobí ref.onDispose, což zavolá db.close()
      // Tím uvolníme soubor db.sqlite pro přepis.
      _ref.invalidate(databaseProvider);

      // Krátké vyčkání na dokončení dispose
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. Přepis starého souboru novým
      final dbFile = await _getDatabaseFile();
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      await backupFile.copy(dbFile.path);
      L.i('Databáze byla přepsána záložním souborem.');

      // 4. Inicializace nové databáze
      // Tím, že vyvoláme čtení databaseProvider, se databáze znovu otevře
      final _ = _ref.read(databaseProvider);

      return true;
    } catch (e, stack) {
      L.e('Chyba při importu zálohy', e, stack);
      return false;
    }
  }
}

/// Provider poskytující instanci [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
