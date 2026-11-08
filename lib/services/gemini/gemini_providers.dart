import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/gemini_models.dart';
import 'gemini_live_client.dart';
import 'gemini_batch_client.dart';
import '../prompt/system_prompt_builder.dart';
import '../audio/audio_providers.dart';
import '../../core/config/config_providers.dart';

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

/// Poskytuje instanci [GeminiBatchClient] pro krátké úlohy (Request-Response): příprava tématu,
/// scénáře, dril, chat nad lekcí a kartičky. Na jeden model čeká nejvýš
/// [GeminiBatchClient.shortTaskTimeout], rozbor lekce má vlastní klient.
final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final modelName = ref.watch(modelProvider);

  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey, modelName, receiveTimeout: GeminiBatchClient.shortTaskTimeout);
});

/// Specializovaný provider pro analýzu dokončených lekcí.
/// 
/// Využívá primárně Gemini 3.8 Flash pro zajištění nejkvalitnějších výsledků analýzy
/// a specifický systémový prompt pro vyhodnocování chyb studenta.
final geminiAnalysisClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  const modelName = GeminiModels.flash3_8;
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(
    apiKey, 
    modelName, 
    systemPrompt: SystemPromptBuilder.buildAnalysisPrompt(),
  );
});

/// Rozhodčí kartiček v lekci: po replice studenta posoudí, jestli zvládl některou kartičku.
/// Volá se často (každá replika v lekci), proto flash-lite s krátkým čekáním.
final geminiLessonJudgeClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(
    apiKey,
    GeminiModels.flashLite3_5,
    fallbackModels: const [GeminiModels.flashLite3_1],
    receiveTimeout: GeminiBatchClient.shortTaskTimeout,
  );
});

/// Specializovaný provider pro Voice Director Agenta (konverzační režisér na pozadí hovoru).
/// 
/// Režisér se volá každé tři repliky studenta, proto běží na flash-lite modelech (500 požadavků
/// denně). Gemini 3.8 a 3.6 Flash mají na bezplatné úrovni jen 20 denně a režisér by je vyčerpal
/// v první lekci, takže by nezbyly na rozbor po lekci a přípravu témat.
final geminiDirectorClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(
    apiKey,
    GeminiModels.flashLite3_5,
    fallbackModels: const [GeminiModels.flashLite3_1],
  );
});

