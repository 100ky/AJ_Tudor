import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../../services/topics/topic_history_backfill.dart';

/// Úpravy profilu studenta z nastavení: úroveň angličtiny, fakta „O mně“
/// a reset paměti tutora.
class ProfileSettingsController {
  final Ref _ref;

  ProfileSettingsController(this._ref);

  /// Nastaví úroveň angličtiny (A1–B2), na kterou se tutor ladí.
  Future<void> setTargetLevel(String level) {
    return _ref.read(profileRepositoryProvider).updateTargetLevel(level);
  }

  /// Přidá fakt „O mně“, který si má tutor pamatovat.
  Future<void> addFact(String fact) {
    return _ref.read(profileRepositoryProvider).addUserFact(fact);
  }

  /// Odebere fakt „O mně“ z paměti tutora.
  Future<void> removeFact(String fact) {
    return _ref.read(profileRepositoryProvider).removeUserFact(fact);
  }

  /// Vymaže vše, co si tutor o studentovi pamatuje, včetně pokroku a evidence témat.
  Future<void> resetMemory() async {
    await _ref.read(profileRepositoryProvider).resetUserMemory();
    await _ref.read(topicHistoryRepositoryProvider).clearAll();
    try {
      await _ref.read(sharedPreferencesProvider).remove(TopicHistoryBackfill.doneKey);
    } catch (_) {}
  }
}

/// Poskytuje [ProfileSettingsController].
final profileSettingsControllerProvider =
    Provider<ProfileSettingsController>(ProfileSettingsController.new);
