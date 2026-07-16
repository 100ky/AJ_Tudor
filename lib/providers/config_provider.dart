import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/gemini_models.dart';

/// Provider pro standardní SharedPreferences (lokální nastavení, která nejsou citlivá).
/// 
/// Hodnota musí být přepsána v `main.dart` po inicializaci pluginu.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

/// Provider pro šifrované úložiště (pro citlivá data jako API klíče).
/// 
/// Používá EncryptedSharedPreferences na Androidu a Keychain na iOS.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Správce API klíče pro Gemini.
/// 
/// Zajišťuje bezpečné uložení klíče a automatickou migraci ze starého
/// nezabezpečeného úložiště (SharedPreferences) do Secure Storage.
class ApiKeyNotifier extends Notifier<String?> {
  static const _key = 'gemini_api_key';

  @override
  String? build() {
    // build() je synchronní, načtení klíče probíhá na pozadí v [_loadKey]
    _loadKey();
    return null;
  }

  /// Asynchronně načte klíč a provede případnou migraci.
  Future<void> _loadKey() async {
    final storage = ref.read(secureStorageProvider);
    final key = await storage.read(key: _key);
    
    // Zpětná kompatibilita: Pokud klíč není v secure storage, zkusíme SharedPreferences
    if (key == null) {
      final prefs = ref.read(sharedPreferencesProvider);
      final oldKey = prefs.getString(_key);
      if (oldKey != null) {
        // Migrace klíče do bezpečného úložiště a smazání starého záznamu
        await saveKey(oldKey);
        await prefs.remove(_key);
        return;
      }
    }
    
    state = key;
  }

  /// Uloží nový API klíč do šifrovaného úložiště.
  Future<void> saveKey(String key) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _key, value: key);
    state = key;
  }
  
  /// Odstraní API klíč z úložiště.
  Future<void> clearKey() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _key);
    state = null;
  }
}

/// Globální přístup k API klíči.
final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

/// Správce vybraného AI modelu pro textový chat.
class ModelNotifier extends Notifier<String> {
  static const _key = 'gemini_model';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_key);
    
    // Validace, zda je uložený model stále v seznamu povolených
    if (saved != null && GeminiModels.allowedChatModels.contains(saved)) {
      return saved;
    }
    // Pokud není vybráno nic nebo neplatný model, použije se výchozí (3.5 Flash)
    return GeminiModels.defaultModel;
  }

  /// Uloží volbu modelu do nastavení.
  Future<void> saveModel(String model) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, model);
    state = model;
  }
}

/// Globální přístup k vybranému modelu.
final modelProvider = NotifierProvider<ModelNotifier, String>(ModelNotifier.new);

/// Správce nastavení připomínek lekcí.
class RemindersNotifier extends Notifier<bool> {
  static const _key = 'reminders_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  /// Zapne nebo vypne notifikace připomínek.
  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

/// Globální stav notifikací.
final remindersEnabledProvider = NotifierProvider<RemindersNotifier, bool>(RemindersNotifier.new);

/// Správce "Otravného režimu" (např. častější notifikace).
class AnnoyingModeNotifier extends Notifier<bool> {
  static const _key = 'annoying_mode';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  /// Zapne nebo vypne otravný režim.
  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

/// Globální stav otravného režimu.
final annoyingModeProvider = NotifierProvider<AnnoyingModeNotifier, bool>(AnnoyingModeNotifier.new);

/// Správce nastaveného času pro denní připomínku.
class ReminderTimeNotifier extends Notifier<String> {
  static const _key = 'reminder_time';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '18:00';
  }

  /// Uloží čas připomínky (formát HH:mm).
  Future<void> saveTime(String time) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, time);
    state = time;
  }
}

/// Globální stav času připomínky.
final reminderTimeProvider = NotifierProvider<ReminderTimeNotifier, String>(ReminderTimeNotifier.new);

/// Správce hlasu pro Gemini Live (např. Puck, Kore, Aoede).
class VoiceNotifier extends Notifier<String> {
  static const _key = 'gemini_voice';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? 'Puck';
  }

  /// Uloží vybraný hlas pro hlasového tutora.
  Future<void> saveVoice(String voice) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, voice);
    state = voice;
  }
}

/// Globální stav vybraného hlasu.
final voiceProvider = NotifierProvider<VoiceNotifier, String>(VoiceNotifier.new);

/// Správce pohlcujícího anglického režimu (Immersive Mode).
/// 
/// V tomto režimu tutor mluví výhradně anglicky a nevyžaduje překlady.
class ImmersiveModeNotifier extends Notifier<bool> {
  static const _key = 'immersive_mode';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  /// Zapne nebo vypne pohlcující režim.
  Future<void> toggle(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}

/// Globální stav pohlcujícího režimu.
final immersiveModeProvider = NotifierProvider<ImmersiveModeNotifier, bool>(ImmersiveModeNotifier.new);
