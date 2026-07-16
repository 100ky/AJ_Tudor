import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/session_repository.dart';

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

/// Poskytuje instanci [SessionRepository] pro práci s výukovými daty.
/// 
/// Tento provider je závislý na [databaseProvider].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SessionRepository(db);
});

