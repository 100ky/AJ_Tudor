import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/grouped_section.dart';
import '../../../data/database/app_database.dart';
import 'session_card.dart';

/// Lekce seskupené po dnech (Dnes, Včera, Neděle 8. 11.), od nejnovější.
class SessionList extends StatelessWidget {
  final List<Session> sessions;
  final EdgeInsetsGeometry padding;

  const SessionList({super.key, required this.sessions, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 32)});

  /// Popisek dne: „Dnes“, „Včera“, „Neděle 8. 11.“, u jiného roku i rok.
  static String dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d == today) return 'Dnes';
    if (d == today.subtract(const Duration(days: 1))) return 'Včera';
    final text = DateFormat(d.year == now.year ? 'EEEE d. M.' : 'EEEE d. M. yyyy', 'cs').format(d);
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final groups = <DateTime, List<Session>>{};
    for (final s in sorted) {
      groups.putIfAbsent(DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day), () => []).add(s);
    }
    final now = DateTime.now();
    final days = groups.keys.toList();

    return ListView.builder(
      padding: padding,
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == days.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'Podržením lekce ji smažeš.',
              style: AppTheme.font(fontSize: 12.5, color: AppTheme.textTertiary),
            ),
          );
        }
        final day = days[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupLabel(dayLabel(day, now)),
            GroupedSection(
              dividerIndent: 62,
              children: [for (final s in groups[day]!) SessionCard(session: s)],
            ),
          ],
        );
      },
    );
  }
}
