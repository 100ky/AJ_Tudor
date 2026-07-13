import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../providers/config_provider.dart';
import '../prompt/system_prompt_builder.dart';

final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey);
});

class GeminiBatchClient {
  late final GenerativeModel _model;
  late final ChatSession chat;

  GeminiBatchClient(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
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
