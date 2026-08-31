import 'package:drift/drift.dart';
import 'error_logs.dart';

/// Tabulka reprezentující kartičky pro intervalové opakování (Spaced Repetition System - SRS).
/// 
/// Umožňuje studentovi procvičovat konkrétní chyby a problematické výrazy z konverzací.
@DataClassName('Flashcard')
class Flashcards extends Table {
  /// Unikátní identifikátor kartičky.
  IntColumn get id => integer().autoIncrement()();

  /// Volitelná reference na konkrétní záznam chyby v chybovém logu.
  IntColumn get errorLogId => integer().nullable().references(ErrorLogs, #id)();

  /// Text na přední straně kartičky (např. česká nápověda, věta k doplnění či otázka).
  TextColumn get frontText => text()();

  /// Správné anglické znění na zadní straně kartičky.
  TextColumn get backText => text()();

  /// České gramatické vysvětlení nebo kontext.
  TextColumn get explanation => text()();

  /// Typ procvičovaného jevu ('grammar' | 'vocabulary' | 'pronunciation' | 'preposition' | 'tense').
  TextColumn get errorType => text().withDefault(const Constant('grammar'))();

  /// Původní věta ze sezení, ve které chyba vznikla.
  TextColumn get sourceSentence => text().nullable()();

  /// Aktuální interval pro opakování ve dnech (algoritmus SRS).
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();

  /// Počet úspěšných po sobě jdoucích zopakování.
  IntColumn get repetitionCount => integer().withDefault(const Constant(0))();

  /// Úroveň zvládnutí kartičky (0.0 = nová, 1.0 = perfektně zvládnutá).
  RealColumn get masteryScore => real().withDefault(const Constant(0.0))();

  /// Čas, kdy má být kartička znovu nabídnuta k procvičení.
  DateTimeColumn get nextReviewAt => dateTime()();

  /// Čas vytvoření kartičky.
  DateTimeColumn get createdAt => dateTime()();
}

