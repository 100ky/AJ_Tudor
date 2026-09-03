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
import 'tables/flashcards.dart';

part 'app_database.g.dart';

/// Hlavní třída databáze aplikace využívající knihovnu Drift (SQLite).
/// 
/// Obsahuje definice všech tabulek a zajišťuje připojení k souboru databáze.
/// Tabulky jsou importovány z oddělených souborů v adresáři 'tables/'.
@DriftDatabase(tables: [Sessions, Transcripts, UserProfiles, ErrorLogs, Scenarios, Flashcards])
class AppDatabase extends _$AppDatabase {
  /// Inicializuje databázi a otevírá připojení k souboru.
  AppDatabase() : super(_openConnection());

  /// Konstruktor pro testy s in-memory databází.
  AppDatabase.forTesting(super.e);



  /// Verze schématu databáze. Při změně struktury tabulek je nutné ji zvýšit.
  @override
  int get schemaVersion => 2;

  /// Definice strategie pro migraci databáze (např. při upgrade verze).
  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Zapnutí podpory cizích klíčů v SQLite
          await customStatement('PRAGMA foreign_keys = ON');

          // 1. Zajištění existence tabulky flashcards
          await customStatement('''
            CREATE TABLE IF NOT EXISTS flashcards (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              error_log_id INTEGER REFERENCES error_logs (id),
              front_text TEXT NOT NULL,
              back_text TEXT NOT NULL,
              explanation TEXT NOT NULL,
              error_type TEXT NOT NULL DEFAULT 'grammar',
              source_sentence TEXT,
              interval_days INTEGER NOT NULL DEFAULT 1,
              repetition_count INTEGER NOT NULL DEFAULT 0,
              mastery_score REAL NOT NULL DEFAULT 0.0,
              next_review_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');

          // 2. Bezpečné přidání sloupce in_flashcard do transcripts pokud ještě neexistuje
          try {
            await customStatement(
                'ALTER TABLE transcripts ADD COLUMN in_flashcard INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {
            // Sloupec již existuje
          }

          // 3. Bezpečné přidání sloupce in_flashcard do error_logs pokud ještě neexistuje
          try {
            await customStatement(
                'ALTER TABLE error_logs ADD COLUMN in_flashcard INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {
            // Sloupec již existuje
          }

          // 4. Synchronizace existujících kartiček s příznaky in_flashcard
          try {
            await customStatement(
                'UPDATE error_logs SET in_flashcard = 1 WHERE id IN (SELECT error_log_id FROM flashcards WHERE error_log_id IS NOT NULL);');
            await customStatement(
                'UPDATE transcripts SET in_flashcard = 1 WHERE content IN (SELECT source_sentence FROM flashcards WHERE source_sentence IS NOT NULL);');
          } catch (_) {}
        },
        onUpgrade: (m, from, to) async {
          // Při vývoji jednoduše vytvoříme všechny chybějící tabulky.
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
