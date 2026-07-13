import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../providers/config_provider.dart';
import '../prompt/system_prompt_builder.dart';

final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final modelName = ref.watch(modelProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey, modelName);
});

class GeminiBatchClient {
  late final GenerativeModel _model;
  late final ChatSession chat;

  GeminiBatchClient(String apiKey, String modelName) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(SystemPromptBuilder.buildTutorPrompt()),
    );
    chat = _model.startChat();
  }

  Future<String> sendMessage(String text) async {
    try {
      final response = await chat.sendMessage(Content.text(text));
      return response.text ?? 'Tutor neodpověděl.';
    } catch (e) {
      return 'Chyba připojení: $e';
    }
  }
}
