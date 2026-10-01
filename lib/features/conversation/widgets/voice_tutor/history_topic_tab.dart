import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../services/agents/topic_preparation_agent.dart';

/// Záložka „Historie“: téma připravené agentem z minulých rozhovorů.
class HistoryTopicTab extends ConsumerWidget {
  const HistoryTopicTab({super.key});

  void _prepareNewTopic(WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(topicPreparationAgentProvider.notifier).prepareTopic(force: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Přechod z načítání na kartu tématu se plynule prolne
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _content(context, ref),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final preparedTopic = topicState.topic;

    if (topicState.isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Příprava tématu z historie...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    if (preparedTopic == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Text(
              'Zatím nemáš připravené téma.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _prepareNewTopic(ref),
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: const Text('Připravit téma z historie'),
            ),
          ],
        ),
      );
    }

    final isRandom = preparedTopic.isRandomTopic;

    return GlassContainer(
      key: const ValueKey('history_topic_card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      color: isRandom
          ? AppTheme.accent.withValues(alpha: 0.08)
          : AppTheme.primary.withValues(alpha: 0.06),
      border: Border.all(
        color: isRandom
            ? AppTheme.accent.withValues(alpha: 0.35)
            : AppTheme.primary.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRandom ? Icons.casino_rounded : Icons.lightbulb_rounded,
                size: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRandom
                      ? 'DIVOKÁ KARTA (NÁHODNÉ TÉMA)'
                      : 'TÉMA NA POKEC Z HISTORIE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _prepareNewTopic(ref),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Jiné téma',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preparedTopic.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '„${preparedTopic.openerEn}“',
            style: GoogleFonts.plusJakartaSans(
              fontStyle: FontStyle.italic,
              fontSize: 12.5,
              color: AppTheme.surfaceTextColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Aktivní téma pro hovor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
