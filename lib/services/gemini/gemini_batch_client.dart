import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';
import 'gemini_rest_core.dart';

/// Klientská třída pro komunikaci s Gemini API v dávkovém/jednorázovém režimu (non-streaming).
///
/// Používá přímé REST volání na Gemini API (bez deprecated google_generative_ai SDK).
/// Obsahuje robustní logiku automatického zotavení (fallback), která při přetížení
/// primárního modelu vyzkouší záložní modely z definovaného seznamu.
class GeminiBatchClient {
  /// API klíč pro přístup ke službám Google Gemini.
  final String apiKey;

  /// Název primárního modelu, který se má přednostně použít.
  final String primaryModelName;

  /// Volitelná systémová instrukce (prompt), která definuje chování modelu.
  final String? systemPrompt;

  final GeminiRestCore _api;

  /// Dočasný cooldown pro modely přetížené chybami 503/429/timeout.
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// Inicializuje klienta s potřebnými konfiguračními údaji.
  GeminiBatchClient(this.apiKey, this.primaryModelName, {this.systemPrompt})
      : _api = GeminiRestCore(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        );

  /// Pokusí se odeslat zprávu a vrátí odpověď modelu jako [String].
  ///
  /// Pokud je primární model přetížený (chyba 429, 503 atd.) nebo neodpoví v limitu,
  /// metoda postupně vyzkouší záložní modely (tzv. "waterfall" / kaskádový fallback).
  ///
  /// [text] je samotná zpráva od uživatele.
  /// [responseSchema] je volitelné schéma pro vynucení strukturovaného JSON výstupu.
  /// [systemPrompt] umožňuje přepsat výchozí systémovou instrukci pro tento konkrétní dotaz.
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) async {
    // Definice pořadí zkoušených modelů (waterfall).
    // Začínáme primárně vybraným modelem a v případě přetížení (429, 503) kaskádovitě
    // přecházíme od nejinteligentnějšího (3.8 Flash) přes silný reasoning (3.1 Pro) až po starší stabilní (3.5 Flash).
    final allCandidates = {
      primaryModelName,
      GeminiModels.flash3_8,
      GeminiModels.flash3_7,
      GeminiModels.pro3_1,
      GeminiModels.flash3_5,
      GeminiModels.flashLite3_1,
    };

    String lastError = '';

    for (final modelName in _cooldowns.order(allCandidates)) {
      try {
        L.i('Zkouším model: $modelName...');

        final result = await _callApi(
          modelName: modelName,
          text: text,
          responseSchema: responseSchema,
          systemPromptOverride: systemPrompt,
          temperature: temperature,
        );

        _cooldowns.markSuccess(modelName);
        if (modelName != primaryModelName) {
          L.w('⚠️ Fallback úspěšný s modelem: $modelName');
        }
        return result;
      } on DioException catch (e) {
        lastError = geminiErrorMessage(e);

        switch (classifyGeminiError(e)) {
          case GeminiErrorKind.auth:
            // Trvalá autentizační chyba – nemá smysl zkoušet další model
            L.e('Trvalá autentizační chyba u $modelName: $lastError');
            return '🔑 Neplatný API klíč. Zkontroluj ho v Nastavení.';
          case GeminiErrorKind.notFound:
            L.w('Model $modelName nebyl nalezen (404). Zkouším další záložní model v pořadí...');
          case GeminiErrorKind.overloaded:
            _cooldowns.markOverloaded(modelName, const Duration(minutes: 3));
            L.w('Model $modelName je přetížený (${e.response?.statusCode ?? 0}). Dávám na 3min cooldown a zkouším další...');
          case GeminiErrorKind.other:
            L.e('Neočekávaná chyba u modelu $modelName: $lastError');
            rethrow; // Vyhodíme výjimku dál, ať to agent umí zpracovat (např. v catch JSON)
        }
      } catch (e) {
        L.e('Neočekávaná chyba u modelu $modelName', e);
        lastError = e.toString();
        throw Exception(lastError); // Vyhodíme Exception pro konzistenci
      }
    }

    // Pokud selžou všechny modely, namísto vracení textu, který rozbije JSON parser,
    // vyhodíme jasnou výjimku, aby se aktivovaly záložní/retry mechanismy v agentech.
    throw Exception('Všechny modely jsou momentálně přetížené. Poslední chyba: $lastError');
  }

  /// Provede přímé REST volání na Gemini generateContent endpoint.
  Future<String> _callApi({
    required String modelName,
    required String text,
    Map<String, dynamic>? responseSchema,
    String? systemPromptOverride,
    double? temperature,
  }) async {
    final effectiveSystemPrompt = systemPromptOverride ??
        systemPrompt ??
        SystemPromptBuilder.buildTutorPrompt();

    // Sestavení těla požadavku dle Gemini REST API v1beta
    final body = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {'text': effectiveSystemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ]
        }
      ],
      if (responseSchema != null || temperature != null)
        'generationConfig': {
          if (responseSchema != null) ...{
            'responseMimeType': 'application/json',
            'responseSchema': responseSchema,
          },
          'temperature': ?temperature,
        },
    };

    final data = await _api
        .generateContent(
          apiKey: apiKey,
          model: modelName,
          body: body,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        )
        .timeout(const Duration(seconds: 55));

    return GeminiRestCore.requireText(data);
  }
}
