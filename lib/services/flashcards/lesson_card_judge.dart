import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../gemini/gemini_batch_client.dart';
import '../gemini/gemini_json.dart';
import '../gemini/gemini_providers.dart';
import '../gemini/gemini_rest_core.dart';
import '../prompt/system_prompt_builder.dart';
import 'conversation_cards.dart';

/// Posoudí, jestli student v lekci nebo v pokecu sám zvládl některou kartičku.
///
/// Doslovné porovnání ([ConversationCards.completeBy]) nestačí: gramatickou kartičku
/// („didn't relax“) student splní i jinou správnou větou („I had no time to rest“)
/// a slovíčko i v jiném tvaru („winterize“ místo „winterized“). Primárně používá
/// Decisions API (`gemini-decision-1`, 10k požadavků denně na Free Tieru, 0 výstupních
/// tokenů), při chybě spadne na `GeminiBatchClient` (flash-lite).
class LessonCardJudge {
  final GeminiBatchClient? _client;
  final String? _apiKey;
  final GeminiRestCore? _decisionApi;

  LessonCardJudge(this._client, {String? apiKey, GeminiRestCore? decisionApi})
      : _apiKey = apiKey,
        _decisionApi = decisionApi ??
            (apiKey != null && apiKey.isNotEmpty
                ? GeminiRestCore(
                    connectTimeout: const Duration(seconds: 5),
                    receiveTimeout: const Duration(seconds: 6),
                  )
                : null);

  /// Kartička z [remaining], kterou student zvládl replikou [studentText], jinak null.
  /// [recentTutorLines] jsou poslední repliky tutora před ní (zopakování po něm se nepočítá).
  Future<ConversationCard?> judge({
    required List<ConversationCard> remaining,
    required List<String> recentTutorLines,
    required String studentText,
  }) async {
    final client = _client;
    final decisionApi = _decisionApi;
    final apiKey = _apiKey;
    if ((client == null && decisionApi == null) || remaining.isEmpty || studentText.trim().isEmpty) {
      return null;
    }

    if (decisionApi != null && apiKey != null && apiKey.isNotEmpty) {
      try {
        final matched = await _judgeWithDecisionsApi(
          decisionApi: decisionApi,
          apiKey: apiKey,
          remaining: remaining,
          recentTutorLines: recentTutorLines,
          studentText: studentText,
        );
        return matched;
      } catch (e) {
        L.w('Decisions API (gemini-decision-1) selhalo, přepínám na záložní flash-lite: $e');
      }
    }

    if (client == null) return null;
    try {
      final raw = await client.sendMessage(
        SystemPromptBuilder.buildLessonJudgeRequest(
          cards: remaining,
          recentTutorLines: recentTutorLines,
          studentText: studentText,
        ),
        systemPrompt: SystemPromptBuilder.lessonJudgeSystem,
        responseSchema: SystemPromptBuilder.getLessonJudgeSchema(),
      );
      final data = decodeModelJson(raw) as Map<String, dynamic>;
      final id = (data['cardId'] as num?)?.toInt() ?? 0;
      for (final card in remaining) {
        if (card.id == id) {
          L.i('🎓 Rozhodčí lekce: kartička #$id splněna (${data['reason'] ?? ''}).');
          return card;
        }
      }
      return null;
    } catch (e) {
      L.w('Rozhodčí lekce neodpověděl, kartička se posoudí jen doslovně: $e');
      return null;
    }
  }

  Future<ConversationCard?> _judgeWithDecisionsApi({
    required GeminiRestCore decisionApi,
    required String apiKey,
    required List<ConversationCard> remaining,
    required List<String> recentTutorLines,
    required String studentText,
  }) async {
    final criteria = <String, String>{
      'none':
          "None of the cards were satisfied by the student's own expression (or the student only repeated what the tutor just said, or made a grammar error in the target grammar, or used a different word for a [slovíčko] card).",
      for (final card in remaining)
        'card_${card.id}': card.kind == CardKind.grammar
            ? "[gramatika] ${card.czech} (e.g. '${card.english}'): Student expressed the meaning '${card.czech}' in their own words with correct grammar, and did not just repeat the tutor."
            : "[slovíčko] ${card.czech} -> '${card.english}': Student used the English expression '${card.english}' (in any verb tense/form and with the meaning '${card.czech}') on their own without repeating the tutor (a synonym does NOT count).",
    };

    final input = SystemPromptBuilder.buildLessonJudgeRequest(
      cards: remaining,
      recentTutorLines: recentTutorLines,
      studentText: studentText,
    );

    final response = await decisionApi.createDecision(
      apiKey: apiKey,
      body: {
        'model': GeminiModels.decision1,
        'input': input,
        'questions': {
          'card': {
            'type': 'choice',
            'instructions': SystemPromptBuilder.lessonJudgeSystem,
            'criteria': criteria,
          },
        },
      },
    );

    final answers = response?['answers'] as Map?;
    final cardAnswer = answers?['card'] as Map?;
    final choice = cardAnswer?['choice']?.toString();
    if (choice == null || choice.isEmpty) {
      throw StateError('Missing choice in Decisions API response: $response');
    }
    if (choice == 'none') return null;

    if (choice.startsWith('card_')) {
      final id = int.tryParse(choice.substring(5));
      for (final card in remaining) {
        if (card.id == id) {
          final conf = (cardAnswer?['confidence'] as num?)?.toDouble();
          L.i('⚖️ Rozhodčí (Decision 1): kartička #$id splněna${conf != null ? ' (jistota ${(conf * 100).round()} %)' : ''}.');
          return card;
        }
      }
    }
    return null;
  }
}

/// Rozhodčí kartiček v lekci i v hovoru (primárně Decisions API, záložně flash-lite).
final lessonCardJudgeProvider = Provider<LessonCardJudge>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  return LessonCardJudge(
    ref.watch(geminiLessonJudgeClientProvider),
    apiKey: apiKey,
  );
});
