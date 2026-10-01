import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/agents/topic_preparation_agent.dart';
import 'agent_card_header.dart';

/// Karta agenta, který po startu a po každé lekci připraví konverzační téma.
class TopicAgentCard extends ConsumerWidget {
  const TopicAgentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final isDark = AppTheme.isDark(context);
    final topic = topicState.topic;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Startup Topic Agent',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    Text(
                      'Příprava témat z historie & paměti „O mně"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              AgentStatusBadge(
                topicState.isLoading ? 'Generuji...' : 'Připraven',
                topicState.isLoading ? AppTheme.accent : AppTheme.success,
                showPulse: topicState.isLoading,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tento agent se probouzí po startu aplikace a po ukončení každého rozhovoru. '
            'Analyzuje transkripty z minulých lekcí a informace, které o vás Tudor ví, '
            'aby navrhl neotřelé konverzační téma a zabránil opakování dotazů (např. na mazlíčky a záliby).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.surfaceTextColor(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (topic != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        topic.isRandomTopic
                            ? Icons.casino_rounded
                            : Icons.lightbulb_rounded,
                        size: 16,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        topic.isRandomTopic
                            ? 'DIVOKÁ KARTA (NÁHODNÉ TÉMA):'
                            : 'AKTUÁLNĚ PŘIPRAVENÉ TÉMA:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topic.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '„${topic.openerEn}“',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: topicState.isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(topicPreparationAgentProvider.notifier)
                          .prepareTopic(force: true);
                    },
              icon: topicState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(topicState.isLoading
                  ? 'Připravuji nové téma...'
                  : 'Přeplánovat téma nyní'),
            ),
          ),
        ],
      ),
    );
  }
}
