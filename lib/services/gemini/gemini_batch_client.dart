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
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota') || msg.contains('429') || msg.contains('rate')) {
        return '⚠️ Vyčerpán limit API. Počkej chvíli a zkus znovu, nebo zkontroluj svůj API klíč na https://aistudio.google.com/';
      } else if (msg.contains('503') || msg.contains('unavailable') || msg.contains('overloaded')) {
        return '⏳ Model je momentálně přetížený. Zkus to za pár sekund znovu.';
      } else if (msg.contains('401') || msg.contains('403') || msg.contains('permission') || msg.contains('api_key')) {
        return '🔑 Neplatný API klíč. Zkontroluj ho v Nastavení.';
      } else if (msg.contains('not found') || msg.contains('404')) {
        return '❌ Model nebyl nalezen. Zkus změnit model v Nastavení.';
      }
      return '❌ Chyba AI: ${e.message}';
    } catch (e) {
      return '❌ Chyba připojení: $e';
    }
  }
}
