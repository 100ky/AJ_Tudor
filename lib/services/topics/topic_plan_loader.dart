import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/utils/logger.dart';
import '../../data/data_providers.dart';
import 'topic_history_backfill.dart';
import 'topic_planner.dart';

/// Spočítá návrh oblastí témat z evidence a nastavení nejdelšího odstupu.
///
/// Když se evidence nepodaří načíst nebo ještě neproběhlo zpětné doplnění existujících
/// lekcí, vrátí [TopicPlan.empty] a prompty zůstanou bez nabídky (jako před zavedením
/// evidence), aby plánovač neoznačil nedávno probrané oblasti jako „nové“.
Future<TopicPlan> loadTopicPlan(Ref ref, {Set<String> exclude = const {}, DateTime? now}) async {
  try {
    // Start hovoru na plán nesmí čekat déle (zaseknutá databáze ho jinak zdrží celý)
    final records = await ref.read(topicHistoryRepositoryProvider).getAll().timeout(const Duration(seconds: 5));
    if (records.isEmpty) {
      final backfillDone = _isBackfillDone(ref);
      if (!backfillDone && await _hasAnalyzedSessions(ref)) {
        L.i('Plán témat: evidence je prázdná a zpětné doplnění ještě neproběhlo, nechávám fallback bez plánu.');
        return TopicPlan.empty;
      }
    }
    final plan = TopicPlanner.plan(
      records,
      now: now ?? DateTime.now(),
      maxRestDays: ref.read(topicRestDaysProvider),
      exclude: exclude,
    );
    L.topic('Plán témat: nabízím ${plan.offers.map((o) => '${o.area.label}${o.isNew ? ' (nová)' : ''}').join(', ')}; '
        'odpočívá ${plan.resting.isEmpty ? 'nic' : plan.restingLabels.join(', ')}.');
    return plan;
  } catch (e) {
    L.w('Plán témat se nepodařilo spočítat: $e');
    return TopicPlan.empty;
  }
}

bool _isBackfillDone(Ref ref) {
  try {
    return ref.read(sharedPreferencesProvider).getBool(TopicHistoryBackfill.doneKey) == true;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasAnalyzedSessions(Ref ref) async {
  try {
    final sessions = await ref.read(sessionRepositoryProvider).watchAllSessions().first.timeout(const Duration(seconds: 2));
    return sessions.any((s) {
      final summary = s.topicSummary?.trim() ?? '';
      return summary.isNotEmpty && summary != 'Bez popisu';
    });
  } catch (_) {
    return false;
  }
}
