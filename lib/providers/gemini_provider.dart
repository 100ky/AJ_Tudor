import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini/gemini_live_client.dart';
import '../services/gemini/gemini_batch_client.dart';
import '../services/prompt/system_prompt_builder.dart';
import 'audio_provider.dart';
import 'config_provider.dart';

/// Poskytuje instanci [GeminiLiveClient] pro hlasovou komunikaci v reálném čase.
/// 
/// Provider automaticky reaguje na změnu API klíče nebo vybraného modelu.
/// Při zániku (dispose) provideru se spojení automaticky ukončí.
final geminiLiveClientProvider = Provider<GeminiLiveClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  // Sledujeme změnu modelu – pokud se změní, provider se přetvoří (re-build)
  ref.watch(modelProvider); 
  final playbackService = ref.watch(audioPlaybackServiceProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  
  final client = GeminiLiveClient(apiKey, playbackService);
  
  // Zajištění úkladu při zavření obrazovky nebo změně nastavení
  ref.onDispose(() => client.disconnect());
  
  return client;
});

/// Poskytuje instanci [GeminiBatchClient] pro standardní textový chat (Request-Response).
/// 
/// Používá se v [ConversationScreen] pro běžné dotazy uživatele.
final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final modelName = ref.watch(modelProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey, modelName);
});

/// Specializovaný provider pro analýzu dokončených lekcí.
/// 
/// Využívá fixní model (Gemini 3.5 Flash) pro zajištění konzistentních výsledků analýzy
/// a specifický systémový prompt pro vyhodnocování chyb studenta.
final geminiAnalysisClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  // Pro analýzu vynutíme 3.5 Flash, který má nejlepší poměr cena/výkon pro strukturovaný výstup
  const modelName = 'gemini-3.5-flash';
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(
    apiKey, 
    modelName, 
    systemPrompt: SystemPromptBuilder.buildAnalysisPrompt(),
  );
});
