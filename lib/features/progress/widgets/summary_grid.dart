import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/profile_repository.dart';

/// Souhrnná čísla v jednom řádku: lekce, čas v hovoru, slovíčka a dny s lekcí.
class SummaryGrid extends StatelessWidget {
  final UserProfile? profile;
  final List<Session> sessions;

  const SummaryGrid({super.key, required this.profile, required this.sessions});

  @override
  Widget build(BuildContext context) {
    var total = Duration.zero;
    for (final s in sessions) {
      if (s.endedAt != null) total += s.endedAt!.difference(s.startedAt);
    }
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final time = hours > 0 ? (minutes > 0 ? '$hours h $minutes' : '$hours h') : '$minutes min';

    final lessons = profile?.totalSessions ?? 0;
    final words = profile?.vocabularyList.length ?? 0;
    final days = sessions.map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)).toSet().length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Stat('$lessons', czechPlural(lessons, 'lekce', 'lekce', 'lekcí')),
          _Stat(time, 'v hovoru'),
          _Stat('$words', czechPlural(words, 'slovíčko', 'slovíčka', 'slovíček')),
          _Stat('$days', '${czechPlural(days, 'den', 'dny', 'dní')} s lekcí'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: AppTheme.font(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          Text(label, style: AppTheme.font(fontSize: 12.5, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
