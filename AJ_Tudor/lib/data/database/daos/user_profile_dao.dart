import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_profiles.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase> with _$UserProfileDaoMixin {
  UserProfileDao(AppDatabase db) : super(db);

  Future<UserProfile> getOrCreateProfile() async {
    final profile = await select(userProfiles).getSingleOrNull();
    if (profile != null) return profile;

    final id = await into(userProfiles).insert(const UserProfilesCompanion(
      recurringErrors: Value('[]'),
      vocabulary: Value('[]'),
      topicPreferences: Value('[]'),
    ));
    return (select(userProfiles)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateProfile(UserProfilesCompanion profileData) {
    return update(userProfiles).write(profileData);
  }
}
