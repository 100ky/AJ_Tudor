import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/logger.dart';
import '../gemini/gemini_batch_client.dart';
import '../gemini/gemini_json.dart';
import '../gemini/gemini_providers.dart';
import '../prompt/system_prompt_builder.dart';
import 'conversation_cards.dart';

/// Posoudí, jestli student v lekci sám zvládl některou kartičku.
///
/// Doslovné porovnání ([ConversationCards.completeBy]) nestačí: gramatickou kartičku
/// („didn't relax“) student splní i jinou správnou větou („I had no time to rest“)
/// a slovíčko i v jiném tvaru („winterize“ místo „winterized“). Volá se jen v lekci
/// a jen když doslovné porovnání nic nenašlo, jeden požadavek na flash-lite na repliku.
class LessonCardJudge {
  final GeminiBatchClient? _client;

  LessonCardJudge(this._client);

  /// Kartička z [remaining], kterou student zvládl replikou [studentText], jinak null.
  /// [recentTutorLines] jsou poslední repliky tutora před ní (zopakování po něm se nepočítá).
  Future<ConversationCard?> judge({
    required List<ConversationCard> remaining,
    required List<String> recentTutorLines,
    required String studentText,
  }) async {
    final client = _client;
    if (client == null || remaining.isEmpty || studentText.trim().isEmpty) return null;
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
}

/// Rozhodčí kartiček v lekci (flash-lite, krátké čekání).
final lessonCardJudgeProvider = Provider<LessonCardJudge>((ref) {
  return LessonCardJudge(ref.watch(geminiLessonJudgeClientProvider));
});
