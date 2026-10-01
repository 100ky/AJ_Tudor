import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/data_providers.dart';

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

  /// Vymaže vše, co si tutor o studentovi pamatuje, včetně pokroku.
  Future<void> resetMemory() {
    return _ref.read(profileRepositoryProvider).resetUserMemory();
  }
}

/// Poskytuje [ProfileSettingsController].
final profileSettingsControllerProvider =
    Provider<ProfileSettingsController>(ProfileSettingsController.new);
