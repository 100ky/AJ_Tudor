import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
import '../../../data/database/app_database.dart';

/// Hodnocení kartičky (Znovu / Těžké / Dobré / Snadné) s doporučením
/// podle skóre odpovědi (výslovnost nebo shoda napsaného textu).
///
/// U každé volby je, kdy se kartička vrátí. Doporučená volba je bílá.
class SrsRatingBar extends StatelessWidget {
  final Flashcard card;

  /// Skóre odpovědi (0.0–1.0), nebo null.
  final double? answerScore;

  /// Student odpověď nevěděl: povolené je jen „Znovu“.
  final bool againOnly;

  /// Volá se s hodnocením 0 (Znovu) … 3 (Snadné).
  final ValueChanged<int> onRate;

  const SrsRatingBar({
    super.key,
    required this.card,
    required this.answerScore,
    this.againOnly = false,
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

  /// „zítra“, „za 3 dny“, „za 6 dní“.
  static String whenAgain(int days) {
    if (days <= 1) return 'zítra';
    return 'za $days ${czechPlural(days, 'den', 'dny', 'dní')}';
  }

  @override
  Widget build(BuildContext context) {
    final recommended = againOnly ? 0 : recommendedRating(answerScore);
    final options = [
      ('Znovu', 1, true),
      ('Těžké', (card.intervalDays * 1.2).ceil(), !againOnly),
      ('Dobré', (card.intervalDays * 2.0).ceil(), !againOnly),
      ('Snadné', (card.intervalDays * 3.0).ceil(), !againOnly),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text('Kdy ti ji ukázat znovu?', style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _RatingButton(
                    label: options[i].$1,
                    sublabel: whenAgain(options[i].$2),
                    isRecommended: recommended == i,
                    onTap: options[i].$3 ? () => onRate(i) : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (recommended >= 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              againOnly ? 'Bez odpovědi se kartička vrátí zítra.' : 'Zvýrazněná volba odpovídá tvé odpovědi.',
              textAlign: TextAlign.center,
              style: AppTheme.font(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final String sublabel;

  /// Null = tlačítko je zakázané.
  final VoidCallback? onTap;
  final bool isRecommended;

  const _RatingButton({required this.label, required this.sublabel, required this.onTap, this.isRecommended = false});

  @override
  Widget build(BuildContext context) {
    final fg = isRecommended ? AppTheme.background : AppTheme.textPrimary;
    final button = Material(
      color: isRecommended ? AppTheme.textPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, maxLines: 1, style: AppTheme.font(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.font(fontSize: 12, color: isRecommended ? const Color(0xFF3A3E46) : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      selected: isRecommended,
      child: onTap == null ? Opacity(opacity: 0.35, child: button) : button,
    );
  }
}
