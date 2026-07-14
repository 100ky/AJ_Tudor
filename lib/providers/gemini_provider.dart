import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini/gemini_live_client.dart';
import '../services/gemini/gemini_batch_client.dart';
import '../services/prompt/system_prompt_builder.dart';
import 'audio_provider.dart';
import 'config_provider.dart';

final geminiLiveClientProvider = Provider<GeminiLiveClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  ref.watch(modelProvider); // Sledujeme změnu modelu pro restart provideru
  final playbackService = ref.watch(audioPlaybackServiceProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  
  final client = GeminiLiveClient(apiKey, playbackService);
  ref.onDispose(() => client.disconnect());
  
  return client;
});

final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final modelName = ref.watch(modelProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey, modelName);
});

final geminiAnalysisClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  // Pro analýzu vynutíme 3.5 Flash pro nejlepší výsledky
  const modelName = 'gemini-3.5-flash';
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(
    apiKey, 
    modelName, 
    systemPrompt: SystemPromptBuilder.buildAnalysisPrompt(),
  );
});
