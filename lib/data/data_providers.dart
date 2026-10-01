import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'models/flashcard_stats.dart';
import 'repositories/flashcard_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/scenario_repository.dart';
import 'repositories/session_repository.dart';

/// Poskytuje globální instanci databáze [AppDatabase].
///
/// Databáze se otevírá při prvním přístupu a automaticky uzavírá
/// při ukončení aplikace (v disposal cyklu Riverpodu).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Zajištění korektního uzavření SQLite spojení
  ref.onDispose(db.close);
  return db;
});

/// Lekce, transkripty a zaznamenané chyby.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

/// Profil studenta (paměť tutora, slovní zásoba, fakta, připravené téma).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

/// Konverzační scénáře hlasového tutora.
final scenarioRepositoryProvider = Provider<ScenarioRepository>((ref) {
  return ScenarioRepository(ref.watch(databaseProvider));
});

/// Kartičky Smart Flashcards a jejich SRS opakování.
final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepository(ref.watch(databaseProvider));
});

/// Živý stream profilu studenta (paměť, fakta, slovní zásoba).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchUserProfile();
});

/// Všechny lekce od nejnovější.
final allSessionsProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchAllSessions();
});

/// Všechny zaznamenané chyby od nejnovější.
final allErrorLogsProvider = StreamProvider<List<ErrorLog>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchAllErrorLogs();
});

/// Agregované statistiky kartiček (zvládnuté, v procesu, k opakování).
final flashcardStatsProvider = StreamProvider<FlashcardStats>((ref) {
  return ref.watch(flashcardRepositoryProvider).watchFlashcardStats();
});
