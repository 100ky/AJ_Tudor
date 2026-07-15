import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../providers/config_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../prompt/system_prompt_builder.dart';

final geminiBatchClientProvider = Provider<GeminiBatchClient?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  final modelName = ref.watch(modelProvider);
  
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiBatchClient(apiKey, modelName);
});

class GeminiBatchClient {
  final String apiKey;
  final String primaryModelName;
  final String? systemPrompt;

  GeminiBatchClient(this.apiKey, this.primaryModelName, {this.systemPrompt});

  /// Pokusí se odeslat zprávu. Pokud je model přetížený, zkusí fallback modely.
  Future<String> sendMessage(String text, {Map<String, dynamic>? responseSchema}) async {
    // Definice waterfall (pořadí fallbacků)
    final modelsToTry = {
      primaryModelName,
      GeminiModels.flashLite3_1,
      GeminiModels.flash2_5,
    }.toList();

    String lastError = '';

    for (var modelName in modelsToTry) {
      try {
        debugPrint('Zkouším model: $modelName...');
        
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt ?? SystemPromptBuilder.buildTutorPrompt()),
          generationConfig: responseSchema != null ? GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: Schema.fromJson(responseSchema),
          ) : null,
        );

        final chat = model.startChat();
        final response = await chat.sendMessage(Content.text(text));
        
        if (response.text != null) {
          if (modelName != primaryModelName) {
            debugPrint('⚠️ Fallback úspěšný s modelem: $modelName');
          }
          return response.text!;
        }
      } on GenerativeAIException catch (e) {
        lastError = e.message;
        final msg = e.message.toLowerCase();
        
        // Pokud je chyba jiná než přetížení/kvóta, nemá cenu zkoušet další model (např. špatný API klíč)
        bool isOverloaded = msg.contains('quota') || 
                           msg.contains('429') || 
                           msg.contains('rate') || 
                           msg.contains('503') || 
                           msg.contains('unavailable') || 
                           msg.contains('overloaded');

        if (!isOverloaded) {
          return _handlePermanentError(e);
        }
        
        debugPrint('Model $modelName je přetížený. Zkouším další v pořadí...');
      } catch (e) {
        debugPrint('Neočekávaná chyba u modelu $modelName: $e');
        lastError = e.toString();
      }
    }

    return '❌ Všechny modely jsou momentálně přetížené. Poslední chyba: $lastError';
  }

  String _handlePermanentError(GenerativeAIException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('401') || msg.contains('403') || msg.contains('permission') || msg.contains('api_key')) {
      return '🔑 Neplatný API klíč. Zkontroluj ho v Nastavení.';
    } else if (msg.contains('not found') || msg.contains('404')) {
      return '❌ Model nebyl nalezen.';
    }
    return '❌ Chyba AI: ${e.message}';
  }
}
