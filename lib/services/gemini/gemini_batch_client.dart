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
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
  }) async {
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
          systemInstruction: Content.system(systemPrompt ?? this.systemPrompt ?? SystemPromptBuilder.buildTutorPrompt()),
          generationConfig: responseSchema != null ? GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _mapToSchema(responseSchema),
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

  /// Manually maps a JSON-like schema map to the Gemini SDK Schema class.
  Schema _mapToSchema(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final description = json['description'] as String?;
    
    switch (typeStr.toUpperCase()) {
      case 'OBJECT':
        final properties = json['properties'] as Map<String, dynamic>?;
        final requiredProps = json['required'] as List<dynamic>?;
        
        return Schema.object(
          properties: properties?.map((key, value) => MapEntry(key, _mapToSchema(value))) ?? {},
          requiredProperties: requiredProps?.cast<String>(),
          description: description,
        );
      case 'ARRAY':
        final items = json['items'] as Map<String, dynamic>;
        return Schema.array(
          items: _mapToSchema(items),
          description: description,
        );
      case 'STRING':
        final enumValues = json['enum'] as List<dynamic>?;
        if (enumValues != null) {
          return Schema.enumString(
            enumValues: enumValues.cast<String>(),
            description: description,
          );
        }
        return Schema.string(description: description);
      case 'NUMBER':
        return Schema.number(description: description);
      case 'INTEGER':
        return Schema.integer(description: description);
      case 'BOOLEAN':
        return Schema.boolean(description: description);
      default:
        return Schema.string(description: description);
    }
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
