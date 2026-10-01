import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/models/flashcard_stats.dart';
import 'collapsible_card.dart';

/// Stav cvičebny: poměr zvládnutých, rozpracovaných a nových kartiček.
class MasteryOverviewCard extends StatelessWidget {
  final FlashcardStats stats;
  final bool expanded;
  final VoidCallback onToggle;

  /// Otevře záložku Kartičky.
  final VoidCallback onOpenFlashcards;

  const MasteryOverviewCard({
    super.key,
    required this.stats,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFlashcards,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleCard(
      icon: Icons.style_rounded,
      color: AppTheme.primary,
      title: 'Stav cvičebny & kartiček',
      subtitle: stats.totalCards > 0
          ? '${stats.masteredCards} z ${stats.totalCards} kartiček zvládnuto'
          : 'Zatím žádné vytvořené kartičky',
      trailing: [
        if (stats.totalCards > 0)
          CardBadge('${stats.masteredPercentage}% hotovo',
              color: AppTheme.success, outlined: true),
      ],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        if (stats.totalCards > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (stats.masteredCards > 0)
                    Flexible(
                      flex: (stats.masteredCards * 100 ~/ stats.totalCards)
                          .clamp(1, 100),
                      child: Container(color: AppTheme.success),
                    ),
                  if (stats.learningCards > 0)
                    Flexible(
                      flex: (stats.learningCards * 100 ~/ stats.totalCards)
                          .clamp(1, 100),
                      child: Container(color: AppTheme.primary),
                    ),
                  if (stats.newCards > 0)
                    Flexible(
                      flex: (stats.newCards * 100 ~/ stats.totalCards)
                          .clamp(1, 100),
                      child: Container(
                        color: AppTheme.outlineColor(context)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniLegend('${stats.masteredCards} zvládnuto', AppTheme.success),
              _MiniLegend('${stats.learningCards} v procesu', AppTheme.primary),
              _MiniLegend('${stats.dueCards} k opakování', AppTheme.accent),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onOpenFlashcards();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.fitness_center_rounded, size: 16),
            label: Text(
              stats.dueCards > 0
                  ? 'Procvičit kartičky (${stats.dueCards} dnes čeká) →'
                  : 'Otevřít Cvičebnu →',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniLegend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppTheme.mutedTextColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
