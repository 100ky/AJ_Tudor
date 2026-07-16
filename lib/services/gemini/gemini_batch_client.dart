import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';

/// Klientská třída pro komunikaci s Gemini API v dávkovém/jednorázovém režimu (non-streaming).
/// 
/// Tato třída zajišťuje odesílání jednotlivých dotazů a zpracování odpovědí.
/// Obsahuje robustní logiku automatického zotavení (fallback), která při přetížení
/// primárního modelu vyzkouší záložní modely z definovaného seznamu.
class GeminiBatchClient {
  /// API klíč pro přístup ke službám Google Gemini.
  final String apiKey;

  /// Název primárního modelu, který se má přednostně použít (např. gemini-1.5-flash).
  final String primaryModelName;

  /// Volitelná systémová instrukce (prompt), která definuje chování modelu.
  final String? systemPrompt;

  /// Inicializuje klienta s potřebnými konfiguračními údaji.
  GeminiBatchClient(this.apiKey, this.primaryModelName, {this.systemPrompt});

  /// Pokusí se odeslat zprávu a vrátí odpověď modelu jako [String].
  /// 
  /// Pokud je primární model přetížený (chyba 429, 503 atd.) nebo neodpoví do 10 sekund,
  /// metoda postupně vyzkouší záložní modely (tzv. "waterfall" / kaskádový fallback).
  /// 
  /// [text] je samotná zpráva od uživatele.
  /// [responseSchema] je volitelné schéma pro vynucení strukturovaného JSON výstupu.
  /// [systemPrompt] umožňuje přepsat výchozí systémovou instrukci pro tento konkrétní dotaz.
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
  }) async {
    // Definice pořadí zkoušených modelů (waterfall).
    // Začínáme primárně vybraným modelem a v případě selhání pokračujeme na záložní.
    final modelsToTry = {
      primaryModelName,
      GeminiModels.flashLite3_1,
      GeminiModels.flash2_5,
    }.toList();

    String lastError = '';

    for (var modelName in modelsToTry) {
      try {
        L.i('Zkouším model: $modelName...');
        
        // Vytvoření instance generativního modelu z Google AI SDK.
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          // Pokud není předán specifický systémový prompt, použije se buď prompt z instance, nebo výchozí prompt tutora.
          systemInstruction: Content.system(systemPrompt ?? this.systemPrompt ?? SystemPromptBuilder.buildTutorPrompt()),
          // Pokud je definováno schéma odpovědi, nastavíme typ na application/json a namapujeme schéma.
          generationConfig: responseSchema != null ? GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _mapToSchema(responseSchema),
          ) : null,
        );

        // Započetí chatu a odeslání zprávy s timeoutem 10 sekund.
        final chat = model.startChat();
        final response = await chat.sendMessage(Content.text(text))
            .timeout(const Duration(seconds: 10));
        
        if (response.text != null) {
          // Pokud byl úspěšný záložní model, zalogujeme varování.
          if (modelName != primaryModelName) {
            L.w('⚠️ Fallback úspěšný s modelem: $modelName');
          }
          return response.text!;
        }
      } on TimeoutException {
        lastError = 'Timeout vypršel (10s)';
        L.w('Model $modelName neodpověděl včas (Timeout 10s). Zkouším další v pořadí...');
      } on GenerativeAIException catch (e) {
        lastError = e.message;
        final msg = e.message.toLowerCase();
        
        // Zjišťujeme, zda se jedná o dočasné přetížení (rate limit, nedostupnost serveru).
        // Pokud je chyba trvalého charakteru (např. špatný API klíč, 403), nemá smysl zkoušet další modely.
        bool isOverloaded = msg.contains('quota') || 
                           msg.contains('429') || 
                           msg.contains('rate') || 
                           msg.contains('503') || 
                           msg.contains('unavailable') || 
                           msg.contains('overloaded');

        if (!isOverloaded) {
          L.e('Trvalá chyba u modelu $modelName: ${e.message}');
          return _handlePermanentError(e);
        }
        
        L.w('Model $modelName je přetížený. Zkouším další v pořadí...');
      } catch (e) {
        L.e('Neočekávaná chyba u modelu $modelName', e);
        lastError = e.toString();
      }
    }

    // Pokud selhaly všechny pokusy, vrátíme chybovou hlášku.
    return '❌ Všechny modely jsou momentálně přetížené. Poslední chyba: $lastError';
  }

  /// Ručně mapuje obecné JSON schéma (definované jako Map) na třídu [Schema] z Gemini SDK.
  /// 
  /// Gemini SDK vyžaduje pro definici strukturovaných výstupů instanci třídy [Schema].
  /// Tato metoda rekurzivně prochází strukturu a vytváří odpovídající typy.
  Schema _mapToSchema(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final description = json['description'] as String?;
    
    switch (typeStr.toUpperCase()) {
      case 'OBJECT':
        final properties = json['properties'] as Map<String, dynamic>?;
        final requiredProps = json['required'] as List<dynamic>?;
        
        return Schema.object(
          // Rekurzivní mapování všech vnitřních vlastností objektu.
          properties: properties?.map((key, value) => MapEntry(key, _mapToSchema(value))) ?? {},
          requiredProperties: requiredProps?.cast<String>(),
          description: description,
        );
      case 'ARRAY':
        final items = json['items'] as Map<String, dynamic>;
        return Schema.array(
          // Rekurzivní mapování typu položek v poli.
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

  /// Zpracuje trvalé chyby (např. neplatný klíč, chybějící model) a vrátí uživatelsky přívětivou zprávu.
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
