import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/profile_repository.dart';

/// Mřížka souhrnných čísel: lekce, čas, slovíčka a aktivní dny.
class SummaryGrid extends StatelessWidget {
  final UserProfile? profile;
  final List<Session> sessions;

  const SummaryGrid({super.key, required this.profile, required this.sessions});

  @override
  Widget build(BuildContext context) {
    Duration totalDuration = Duration.zero;
    for (var s in sessions) {
      if (s.endedAt != null) {
        totalDuration += s.endedAt!.difference(s.startedAt);
      }
    }
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final timeString = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final vocabCount = profile?.vocabularyList.length ?? 0;

    final activeDays = sessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _GridCard('Lekce', '${profile?.totalSessions ?? 0}',
            Icons.play_lesson_rounded, AppTheme.primary),
        _GridCard('Čas', timeString, Icons.timer_rounded, AppTheme.accent),
        _GridCard('Slovíčka', '$vocabCount', Icons.abc_rounded, AppTheme.success),
        _GridCard('Aktivní dny', '$activeDays',
            Icons.local_fire_department_rounded, AppTheme.error),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _GridCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
