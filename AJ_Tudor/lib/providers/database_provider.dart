import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final sessionDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).sessionDao;
});

final transcriptDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).transcriptDao;
});

final userProfileDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).userProfileDao;
});

final errorLogDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).errorLogDao;
});
