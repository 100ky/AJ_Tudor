import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';

/// Hodnocení kartičky (Znovu / Těžké / Dobré / Snadné) s doporučením
/// podle skóre výslovnosti, pokud student odpovídal hlasem.
class SrsRatingBar extends StatelessWidget {
  final Flashcard card;

  /// Skóre poslední mluvené odpovědi (0.0–1.0), nebo null.
  final double? pronunciationScore;

  /// Volá se s hodnocením 0 (Znovu) … 3 (Snadné).
  final ValueChanged<int> onRate;

  const SrsRatingBar({
    super.key,
    required this.card,
    required this.pronunciationScore,
    required this.onRate,
  });

  /// Hodnocení doporučené podle skóre výslovnosti (−1 = bez doporučení).
  static int recommendedRating(double? score) {
    if (score == null) return -1;
    if (score >= 0.85) return 3; // Snadné
    if (score >= 0.65) return 2; // Dobré
    if (score >= 0.40) return 1; // Těžké
    return 0; // Znovu
  }

  @override
  Widget build(BuildContext context) {
    final recommended = recommendedRating(pronunciationScore);

    return Row(
      children: [
        // Znovu
        Expanded(
          child: _RatingButton(
            icon: Icons.replay_rounded,
            label: 'Znovu',
            sublabel: '1 den',
            color: AppTheme.error,
            isRecommended: recommended == 0,
            onTap: () => onRate(0),
          ),
        ),
        const SizedBox(width: 8),
        // Těžké
        Expanded(
          child: _RatingButton(
            icon: Icons.schedule_rounded,
            label: 'Těžké',
            sublabel: '${(card.intervalDays * 1.2).ceil()} d.',
            color: AppTheme.warning,
            isRecommended: recommended == 1,
            onTap: () => onRate(1),
          ),
        ),
        const SizedBox(width: 8),
        // Dobré
        Expanded(
          child: _RatingButton(
            icon: Icons.check_rounded,
            label: 'Dobré',
            sublabel: '${(card.intervalDays * 2.0).ceil()} d.',
            color: AppTheme.primary,
            isRecommended: recommended == 2,
            onTap: () => onRate(2),
          ),
        ),
        const SizedBox(width: 8),
        // Snadné
        Expanded(
          child: _RatingButton(
            icon: Icons.done_all_rounded,
            label: 'Snadné',
            sublabel: '${(card.intervalDays * 3.0).ceil()} d.',
            color: AppTheme.success,
            isRecommended: recommended == 3,
            onTap: () => onRate(3),
          ),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool isRecommended;

  const _RatingButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isRecommended
              ? color.withValues(alpha: 0.22)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecommended ? color : color.withValues(alpha: 0.35),
            width: isRecommended ? 1.8 : 1.0,
          ),
          boxShadow: isRecommended
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecommended)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'DOPORUČENO',
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
