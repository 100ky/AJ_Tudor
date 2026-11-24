import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_providers.dart';
import '../../core/utils/logger.dart';
import '../../data/data_providers.dart';
import 'topic_planner.dart';

/// Spočítá návrh oblastí témat z evidence a nastavení nejdelšího odstupu.
///
/// Když se evidence nepodaří načíst, vrátí [TopicPlan.empty] a prompty zůstanou
/// bez nabídky (jako před zavedením evidence).
Future<TopicPlan> loadTopicPlan(Ref ref, {Set<String> exclude = const {}, DateTime? now}) async {
  try {
    // Start hovoru na plán nesmí čekat déle (zaseknutá databáze ho jinak zdrží celý)
    final records = await ref.read(topicHistoryRepositoryProvider).getAll().timeout(const Duration(seconds: 5));
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
