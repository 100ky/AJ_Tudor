import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_providers.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../audio/pcm_wav.dart';
import '../prompt/task_prompts.dart';
import 'gemini_rest_core.dart';

/// Opravný přepis repliky studenta z jejího nahraného zvuku.
///
/// Živý přepis Gemini Live občas zapíše češtinu nebo angličtinu jiným jazykem
/// („¿Qué?“, „Jeden Tag nach der Schule“) a konverzačnímu modelu se jazyk přepisu
/// nastavit nedá. Stejný zvuk se proto po replice přepíše znovu běžným modelem
/// s pokynem, že student mluví česky nebo anglicky.
class SpeechTranscriptionService {
  final Ref _ref;
  final GeminiRestCore _api;

  /// Cooldown přetížených modelů a naposledy funkční model.
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// Rychlé modely s audio vstupem. Přepisuje se každá replika studenta, proto se začíná
  /// flash-lite (500 požadavků denně). 3.6 Flash má jen 20 denně: dřív ho první hodinu
  /// hovoru spotřeboval opravný přepis a rozbor po lekci pak skončil na flash-lite (lekce 22).
  static const List<String> models = [
    GeminiModels.flashLite3_5,
    GeminiModels.flashLite3_1,
    GeminiModels.flash3_6,
  ];

  static final RegExp _silence = RegExp(r'^\(ticho\)\.?$', caseSensitive: false);

  /// Jak dlouho čekat na odpověď jednoho modelu. Přepis repliky běžně trvá 1–5 s a celý
  /// opravný přepis má 20 s, takže se při zaseknutém modelu stihne zkusit další
  /// (lekce 22: flash-lite neodpovídal 20 s a uložil se jen neúplný živý přepis).
  static const Duration modelTimeout = Duration(seconds: 9);

  /// [api] lze v testech nahradit vlastním REST jádrem.
  SpeechTranscriptionService(this._ref, {GeminiRestCore? api})
      : _api = api ??
            GeminiRestCore(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: modelTimeout,
            );

  /// Resetuje cooldowny modelů (pro testy).
  static void resetState() => _cooldowns.clear();

  /// Přepíše zvuk [pcm16] (PCM 16-bit, 16 kHz, mono).
  ///
  /// Vrátí prázdný text, když v nahrávce žádná řeč není, a null, když se přepis
  /// nepodařil – pak platí živý přepis z Gemini Live.
  Future<String?> transcribe(List<int> pcm16, {String? previousTutorLine}) async {
    if (pcm16.isEmpty) return null;
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) return null;

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': TaskPrompts.speechTranscriptionSystem}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {
                'mimeType': 'audio/wav',
                'data': base64Encode(pcm16ToWav(pcm16)),
              }
            },
            {'text': TaskPrompts.speechTranscriptionRequest(previousTutorLine: previousTutorLine)},
          ]
        }
      ],
    };

    for (final model in _cooldowns.order(models, preferLastWorking: true)) {
      try {
        final data = await _api.generateContent(apiKey: apiKey, model: model, body: body);
        final text = GeminiRestCore.extractText(data);
        if (text == null) continue;
        _cooldowns.markSuccess(model, remember: true);
        final clean = stripModelFormatting(text);
        if (TaskPrompts.isTranscriptionPromptEcho(clean)) {
          L.w('Opravný přepis: model $model vrátil místo přepisu své zadání, výsledek zahazuji.');
          return null;
        }
        return _silence.hasMatch(clean) ? '' : clean;
      } on DioException catch (e) {
        final kind = classifyGeminiError(e);
        if (kind == GeminiErrorKind.auth) {
          // Neplatný klíč odmítnou všechny modely – další pokusy jen zdržují.
          L.w('Opravný přepis: API klíč byl odmítnut (${e.response?.statusCode}), další modely nezkouším.');
          break;
        }
        if (kind == GeminiErrorKind.overloaded) {
          final isNetworkError = e.error is SocketException || e.type == DioExceptionType.connectionError;
          if (isNetworkError) {
             L.w('Opravný přepis: chyba sítě (bez internetu).');
             return null;
          }
          _cooldowns.markFailure(model, e, otherwise: const Duration(minutes: 2));
          L.w(isDailyQuotaError(e)
              ? 'Opravný přepis: model $model vyčerpal denní limit, do obnovy kvóty ho vynechám.'
              : 'Opravný přepis: model $model je přetížený (${e.response?.statusCode ?? 0}), zkouším další...');
        } else {
          L.w('Opravný přepis: model $model selhal ($e), zkouším další...');
        }
      } catch (e) {
        L.w('Opravný přepis: model $model selhal ($e), zkouším další...');
      }
    }
    return null;
  }
}

/// Poskytuje [SpeechTranscriptionService].
final speechTranscriptionServiceProvider =
    Provider<SpeechTranscriptionService>((ref) => SpeechTranscriptionService(ref));
