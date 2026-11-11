import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
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
      title: 'Kartičky',
      subtitle: stats.totalCards > 0
          ? '${stats.masteredCards} z ${stats.totalCards} umíš'
              '${stats.dueCards > 0 ? ', ${stats.dueCards} dnes čeká' : ''}'
          : 'Zatím žádné kartičky',
      trailing: [
        if (stats.totalCards > 0) CardBadge('${stats.masteredPercentage} %'),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.style_rounded, size: 18),
            label: Text(
              stats.dueCards > 0
                  ? 'Procvičit ${stats.dueCards} ${czechPlural(stats.dueCards, 'kartičku', 'kartičky', 'kartiček')}'
                  : 'Otevřít kartičky',
              style: GoogleFonts.hankenGrotesk(
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
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            color: AppTheme.mutedTextColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
