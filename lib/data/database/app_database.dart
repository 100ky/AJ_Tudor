import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'tables/sessions.dart';
import 'tables/transcripts.dart';
import 'tables/user_profiles.dart';
import 'tables/error_logs.dart';
import 'tables/scenarios.dart';

part 'app_database.g.dart';

/// Hlavní třída databáze aplikace využívající knihovnu Drift (SQLite).
/// 
/// Obsahuje definice všech tabulek a zajišťuje připojení k souboru databáze.
/// Tabulky jsou importovány z oddělených souborů v adresáři 'tables/'.
@DriftDatabase(tables: [Sessions, Transcripts, UserProfiles, ErrorLogs, Scenarios])
class AppDatabase extends _$AppDatabase {
  /// Inicializuje databázi a otevírá připojení k souboru.
  AppDatabase() : super(_openConnection());

  /// Verze schématu databáze. Při změně struktury tabulek je nutné ji zvýšit.
  @override
  int get schemaVersion => 1;

  /// Definice strategie pro migraci databáze (např. při upgrade verze).
  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Zapnutí podpory cizích klíčů v SQLite
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          // Při vývoji jednoduše vytvoříme všechny chybějící tabulky.
          // V produkci by zde byla specifická migrační logika.
          await m.createAll();
        },
      );
}

/// Pomocná funkce pro otevření připojení k databázovému souboru.
/// 
/// Na Androidu a iOS ukládá data do systémové složky dokumentů.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Získání cesty ke složce dokumentů aplikace
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    // Nastavení dočasné složky pro SQLite (řeší problémy s některými verzemi Androidu)
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    // Vytvoření nativního připojení, které běží na pozadí (neblokuje UI)
    return NativeDatabase.createInBackground(file);
  });
}
