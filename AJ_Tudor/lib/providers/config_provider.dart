import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider pro synchronní přístup k SharedPreferences instanci (inicializuje se v main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

// Notifier pro správu API klíče
class ApiKeyNotifier extends Notifier<String?> {
  static const _apiKeyKey = 'gemini_api_key';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_apiKeyKey);
  }

  Future<void> setApiKey(String key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_apiKeyKey, key.trim());
    state = key.trim();
  }

  Future<void> clearApiKey() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_apiKeyKey);
    state = null;
  }
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String?>(() {
  return ApiKeyNotifier();
});
