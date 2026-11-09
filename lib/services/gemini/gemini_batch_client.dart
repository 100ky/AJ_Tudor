import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';
import 'gemini_rest_core.dart';

/// Požadavek se na server nedostal: telefon je bez sítě, nebo systém aplikaci
/// na pozadí odpojil (9. 11.: displej zhasl hned po hovoru a rozbor lekce selhal).
class GeminiNetworkException implements Exception {
  const GeminiNetworkException();

  @override
  String toString() => 'Exception: Chyba sítě (bez internetu). Zkontrolujte připojení.';
}

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

  /// Záložní modely po [primaryModelName]; null = výchozí řetězec ([defaultFallbackModels]).
  final List<String>? fallbackModels;

  /// Výchozí záložní modely: od nejschopnějšího k flash-lite s vyšším denním limitem.
  /// gemini-3.1-pro-preview tu není, na bezplatné úrovni vždy vrátí 429.
  static const List<String> defaultFallbackModels = [
    GeminiModels.flash3_8,
    GeminiModels.flash3_6,
    GeminiModels.flashLite3_5,
    GeminiModels.flashLite3_1,
  ];

  /// Dočasný cooldown pro modely přetížené chybami 503/429/timeout.
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// Jak dlouho čekat na odpověď jednoho modelu u rozboru celé lekce (dlouhý vstup i výstup).
  static const Duration longTaskTimeout = Duration(seconds: 45);

  /// Jak dlouho čekat na jeden model u krátkých úloh (téma, dril, chat, kartičky). Zaseknutý
  /// model se tak přeskočí dřív: příprava tématu 8. 11. čekala na 3.8 Flash 45 s, než
  /// 3.6 Flash téma připravil za 7 s.
  static const Duration shortTaskTimeout = Duration(seconds: 20);

  /// Inicializuje klienta s potřebnými konfiguračními údaji.
  GeminiBatchClient(
    this.apiKey,
    this.primaryModelName, {
    this.systemPrompt,
    this.fallbackModels,
    Duration receiveTimeout = longTaskTimeout,
  }) : _api = GeminiRestCore(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: receiveTimeout,
        );

  /// Pokusí se odeslat zprávu a vrátí odpověď modelu jako [String].
  ///
  /// Pokud je primární model přetížený (chyba 429, 503 atd.) nebo neodpoví v limitu,
  /// metoda postupně vyzkouší záložní modely (tzv. "waterfall" / kaskádový fallback).
  ///
  /// [text] je samotná zpráva od uživatele.
  /// [responseSchema] je volitelné schéma pro vynucení strukturovaného JSON výstupu.
  /// [systemPrompt] umožňuje přepsat výchozí systémovou instrukci pro tento konkrétní dotaz.
  ///
  /// Teplota se neposílá: modely Gemini 3.6+ a 4 ji ignorují a u starších Gemini 3
  /// dokumentace radí nechat výchozí hodnotu, jinak se zhoršuje uvažování.
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
  }) async {
    // Pořadí zkoušených modelů (waterfall): primární model, pak záložní. Při přetížení (503)
    // nebo vyčerpané kvótě (429) se přechází na další.
    final allCandidates = {primaryModelName, ...(fallbackModels ?? defaultFallbackModels)};

    String lastError = '';

    for (final modelName in _cooldowns.order(allCandidates)) {
      try {
        L.i('Zkouším model: $modelName...');

        final result = await _callApi(
          modelName: modelName,
          text: text,
          responseSchema: responseSchema,
          systemPromptOverride: systemPrompt,
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
            final isNetworkError = e.error is SocketException || e.type == DioExceptionType.connectionError;
            if (isNetworkError) {
              L.e('Chyba sítě (bez internetu), přerušuji zkoušení dalších modelů.');
              throw const GeminiNetworkException();
            }
            final cooldown = _cooldowns.markFailure(modelName, e, otherwise: const Duration(minutes: 3));
            L.w(isDailyQuotaError(e)
                ? 'Model $modelName vyčerpal denní limit, vynechám ho ${cooldown.inHours} h. Zkouším další...'
                : 'Model $modelName je přetížený (${e.response?.statusCode ?? 0}). Dávám na ${cooldown.inMinutes}min cooldown a zkouším další...');
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
      if (responseSchema != null)
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': responseSchema,
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
