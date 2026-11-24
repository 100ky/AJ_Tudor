import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/config_providers.dart';
import '../../core/utils/logger.dart';
import '../../data/data_providers.dart';
import '../gemini/gemini_providers.dart';
import '../prompt/system_prompt_builder.dart';
import 'lesson_topics.dart';

/// Jednorázově doplní evidenci témat ze souhrnů starších lekcí.
///
/// Evidence vznikla 21. 11. 2026. Bez doplnění by plánovač v prvních dnech považoval
/// za nové i oblasti, o kterých se mluvilo pořád (práce a IT), a nabízel by je.
class TopicHistoryBackfill {
  TopicHistoryBackfill(this._ref);

  final Ref _ref;
  Future<void>? _running;

  /// Klíč v nastavení: doplnění proběhlo (nebo evidence už měla témata).
  static const String doneKey = 'topic_history_backfill_done';

  /// Kolik nejnovějších lekcí se zařadí.
  static const int sessionLimit = 40;

  /// Doplní evidenci, pokud je prázdná a ještě se nedoplňovala. Souběžná volání
  /// počkají na jedno doplnění.
  Future<void> ensure() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      if (prefs.getBool(doneKey) == true) return;
      final repo = _ref.read(topicHistoryRepositoryProvider);
      if (!await repo.isEmpty()) {
        await prefs.setBool(doneKey, true);
        return;
      }
      final gemini = _ref.read(geminiBatchClientProvider);
      if (gemini == null) return;

      final sessions = (await _ref.read(sessionRepositoryProvider).watchAllSessions().first)
          .where((s) {
            final summary = s.topicSummary?.trim() ?? '';
            return summary.isNotEmpty && summary != 'Bez popisu';
          })
          .take(sessionLimit)
          .toList();
      if (sessions.isEmpty) return;

      final dateFormat = DateFormat('d. M. yyyy');
      final lines = sessions.map((s) => '#${s.id} (${dateFormat.format(s.startedAt)}): ${s.topicSummary!.trim()}');
      L.i('🗂️ Evidence témat je prázdná, zařazuji ${sessions.length} starších lekcí podle souhrnů...');
      final response = await gemini.sendMessage(
        lines.join('\n'),
        systemPrompt: SystemPromptBuilder.buildTopicBackfillPrompt(),
        responseSchema: SystemPromptBuilder.getTopicBackfillSchema(),
      );

      final byId = {for (final s in sessions) s.id: s};
      var saved = 0;
      final data = jsonDecode(response);
      for (final item in (data is Map ? data['sessions'] as List? : null) ?? const []) {
        if (item is! Map) continue;
        final session = byId[int.tryParse('${item['sessionId']}')];
        if (session == null) continue;
        final topics = parseLessonTopics(item['topics']);
        if (topics.isEmpty) continue;
        await repo.replaceForSession(session.id, session.startedAt, topics);
        saved += topics.length;
      }
      L.i('🗂️ Evidence témat doplněna: $saved témat z ${sessions.length} lekcí.');
      await prefs.setBool(doneKey, true);
    } catch (e) {
      // Zkusí se znovu při dalším spuštění, plánovač zatím bere evidenci, jaká je
      L.w('🗂️ Doplnění evidence témat se nepovedlo: $e');
    }
  }
}

final topicHistoryBackfillProvider = Provider<TopicHistoryBackfill>(TopicHistoryBackfill.new);
