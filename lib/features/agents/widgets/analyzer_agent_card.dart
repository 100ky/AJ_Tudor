import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/app_database.dart';
import '../../../services/agents/voice_tutor_agent.dart';
import 'agent_card_header.dart';

/// Karta analytika: výsledky poslední analýzy a pedagogický zápis v paměti.
class AnalyzerAgentCard extends StatelessWidget {
  final UserProfile? profile;
  final Session? lastSession;
  final TutorState tutorStatus;

  const AnalyzerAgentCard({
    super.key,
    required this.profile,
    required this.lastSession,
    required this.tutorStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isAnalyzing = tutorStatus == TutorState.connecting ||
        tutorStatus == TutorState.thinking;
    final fluencyScore = lastSession?.fluencyScore;
    final fluencyPercent =
        fluencyScore != null ? (fluencyScore * 100).toInt() : null;
    final profile = this.profile;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentCardHeader(
            icon: Icons.analytics,
            color: AppTheme.success,
            title: '2. Analytik skóre',
            subtitle: 'Agent pro sémantickou analýzu pokroku',
            badge: AgentStatusBadge(
              isAnalyzing ? 'ČEKÁ NA KONEC RELACE' : 'AKTIVNÍ',
              isAnalyzing ? AppTheme.warning : AppTheme.success,
            ),
          ),
          Divider(color: AppTheme.outlineLightColor(context), height: 24),
          Text(
            'Poslední sémantická analýza:',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _MetricItem(
                      label: 'Plynulost',
                      value: fluencyPercent != null ? '$fluencyPercent%' : 'N/A',
                      color: AppTheme.primary)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricItem(
                      label: 'Zjištěná Úroveň',
                      value: profile?.targetLevel ?? 'B1',
                      color: AppTheme.success)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricItem(
                      label: 'Celkem chyb',
                      value: lastSession?.totalErrors != null
                          ? '${lastSession!.totalErrors}'
                          : '0',
                      color: AppTheme.error)),
            ],
          ),
          if (profile?.memoryBriefing != null &&
              profile!.memoryBriefing!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Pedagogický zápis v paměti:',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.mutedTextColor(context)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.15)),
              ),
              child: Text(
                profile.memoryBriefing!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: AppTheme.surfaceTextColor(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, color: AppTheme.mutedTextColor(context)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
