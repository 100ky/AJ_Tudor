import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.watchUserProfile();
});
