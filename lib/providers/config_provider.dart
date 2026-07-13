import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider pro SharedPreferences instanci (inicializován v main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

// Notifier pro API klíč
class ApiKeyNotifier extends Notifier<String?> {
  static const _key = 'gemini_api_key';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  Future<void> saveKey(String key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, key);
    state = key;
  }
  
  Future<void> clearKey() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
    state = null;
  }
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);
