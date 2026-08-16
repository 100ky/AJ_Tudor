import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';

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

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final Dio _dio;

  /// Inicializuje klienta s potřebnými konfiguračními údaji.
  GeminiBatchClient(this.apiKey, this.primaryModelName, {this.systemPrompt})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

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
      GeminiModels.flashLite3_5,
      GeminiModels.flash3_5,
    }.toList();

    String lastError = '';

    for (var modelName in modelsToTry) {
      try {
        L.i('Zkouším model: $modelName...');

        final result = await _callApi(
          modelName: modelName,
          text: text,
          responseSchema: responseSchema,
          systemPromptOverride: systemPrompt,
        );

        if (modelName != primaryModelName) {
          L.w('⚠️ Fallback úspěšný s modelem: $modelName');
        }
        return result;
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode ?? 0;
        lastError = _extractErrorMessage(e);

        // Trvalé chyby (401, 403, 404) – nemá smysl zkoušet další model
        if (statusCode == 401 || statusCode == 403) {
          L.e('Trvalá autentizační chyba u $modelName: $lastError');
          return _handlePermanentError(statusCode, lastError);
        }
        if (statusCode == 404) {
          L.e('Model $modelName nebyl nalezen (404).');
          return '❌ Model nebyl nalezen.';
        }

        // Dočasné přetížení – zkusíme další model
        final isOverloaded = statusCode == 429 ||
            statusCode == 503 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout;

        if (isOverloaded) {
          L.w('Model $modelName je přetížený ($statusCode). Zkouším další v pořadí...');
        } else {
          L.e('Neočekávaná chyba u modelu $modelName: $lastError');
          lastError = lastError;
        }
      } catch (e) {
        L.e('Neočekávaná chyba u modelu $modelName', e);
        lastError = e.toString();
      }
    }

    return '❌ Všechny modely jsou momentálně přetížené. Poslední chyba: $lastError';
  }

  /// Provede přímé REST volání na Gemini generateContent endpoint.
  Future<String> _callApi({
    required String modelName,
    required String text,
    Map<String, dynamic>? responseSchema,
    String? systemPromptOverride,
  }) async {
    final url = '$_baseUrl/$modelName:generateContent?key=$apiKey';

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

    final response = await _dio
        .post<Map<String, dynamic>>(
          url,
          data: body,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        )
        .timeout(const Duration(seconds: 40));

    final data = response.data;
    if (data == null) throw Exception('Prázdná odpověď od serveru');

    // Parsování odpovědi dle Gemini REST formátu
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Žádní kandidáti v odpovědi: $data');
    }

    final content = candidates[0]['content'];
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Žádné části v odpovědi: $content');
    }

    final resultText = parts[0]['text'] as String?;
    if (resultText == null || resultText.isEmpty) {
      throw Exception('Prázdný text v odpovědi');
    }

    return resultText;
  }

  /// Extrahuje čitelnou chybovou zprávu z DioException.
  String _extractErrorMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data['error']?['message']?.toString() ?? e.message ?? e.toString();
      }
    } catch (_) {}
    return e.message ?? e.toString();
  }

  /// Zpracuje trvalé chyby (neplatný klíč, chybějící oprávnění) a vrátí uživatelsky přívětivou zprávu.
  String _handlePermanentError(int statusCode, String message) {
    if (statusCode == 401 || statusCode == 403) {
      return '🔑 Neplatný API klíč. Zkontroluj ho v Nastavení.';
    }
    return '❌ Chyba AI: $message';
  }
}
