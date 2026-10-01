import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/agents/topic_preparation_agent.dart';

/// Téma připravené agentem pro příští hlasovou lekci.
class PreparedTopicCard extends ConsumerWidget {
  const PreparedTopicCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicState = ref.watch(topicPreparationAgentProvider);

    if (topicState.isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Tudor připravuje nové originální téma z historie...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final topic = topicState.topic;
    if (topic == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppTheme.onSurfaceMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Zatím není připraveno žádné téma.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Připravit téma',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                ref.read(topicPreparationAgentProvider.notifier).prepareTopic(force: true);
              },
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primary.withValues(alpha: 0.05),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  topic.isRandomTopic
                      ? Icons.casino_rounded
                      : Icons.auto_awesome_rounded,
                  color: AppTheme.accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topic.isRandomTopic)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'DIVOKÁ KARTA (NÁHODNÉ TÉMA)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    Text(
                      topic.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Vyměnit téma',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: AppTheme.primary,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(topicPreparationAgentProvider.notifier).prepareTopic(force: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondaryColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.openerEn,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textColor(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (topic.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              topic.rationale,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
