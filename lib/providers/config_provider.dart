import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/gemini_models.dart';

// Provider pro SharedPreferences instanci
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

// Provider pro Secure Storage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

// Notifier pro API klíč (nyní v Secure Storage)
class ApiKeyNotifier extends Notifier<String?> {
  static const _key = 'gemini_api_key';

  @override
  String? build() {
    // build() nemůže být asynchronní, takže načtení uděláme v init nebo se spolehneme na state update
    _loadKey();
    return null;
  }

  Future<void> _loadKey() async {
    final storage = ref.read(secureStorageProvider);
    final key = await storage.read(key: _key);
    
    // Fallback na SharedPreferences (migrace)
    if (key == null) {
      final prefs = ref.read(sharedPreferencesProvider);
      final oldKey = prefs.getString(_key);
      if (oldKey != null) {
        await saveKey(oldKey);
        await prefs.remove(_key); // Smazat po migraci
        return;
      }
    }
    
    state = key;
  }

  Future<void> saveKey(String key) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _key, value: key);
    state = key;
  }
  
  Future<void> clearKey() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _key);
    state = null;
  }
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

// Notifier pro vybraný model Gemini
class ModelNotifier extends Notifier<String> {
  static const _key = 'gemini_model';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_key);
    if (saved != null && GeminiModels.allowedChatModels.contains(saved)) {
      return saved;
    }
    // Uložený model je zastaralý nebo žádný není → resetovat na výchozí
    return GeminiModels.defaultModel;
  }

  Future<void> saveModel(String model) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, model);
    state = model;
  }
}

final modelProvider = NotifierProvider<ModelNotifier, String>(ModelNotifier.new);

// Notifier pro upozornění (Reminders)
class RemindersNotifier extends Notifier<bool> {
  static const _key = 'reminders_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

final remindersEnabledProvider = NotifierProvider<RemindersNotifier, bool>(RemindersNotifier.new);

// Notifier pro "Otravný režim"
class AnnoyingModeNotifier extends Notifier<bool> {
  static const _key = 'annoying_mode';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

final annoyingModeProvider = NotifierProvider<AnnoyingModeNotifier, bool>(AnnoyingModeNotifier.new);

// Notifier pro čas upozornění
class ReminderTimeNotifier extends Notifier<String> {
  static const _key = 'reminder_time';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '18:00';
  }

  Future<void> saveTime(String time) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, time);
    state = time;
  }
}

final reminderTimeProvider = NotifierProvider<ReminderTimeNotifier, String>(ReminderTimeNotifier.new);

// Notifier pro vybraný hlas Gemini Live (Puck, Kore, Aoede, Fenrir, Charon)
class VoiceNotifier extends Notifier<String> {
  static const _key = 'gemini_voice';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? 'Puck';
  }

  Future<void> saveVoice(String voice) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, voice);
    state = voice;
  }
}

final voiceProvider = NotifierProvider<VoiceNotifier, String>(VoiceNotifier.new);

// Notifier pro pohlcující anglický režim (Immersive Mode)
class ImmersiveModeNotifier extends Notifier<bool> {
  static const _key = 'immersive_mode';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

final immersiveModeProvider = NotifierProvider<ImmersiveModeNotifier, bool>(ImmersiveModeNotifier.new);
