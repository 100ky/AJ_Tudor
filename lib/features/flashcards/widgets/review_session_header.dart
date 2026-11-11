import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Postup v aktuálním opakování: „Kartička X z Y“, kolik už umíš a tenký proužek.
class ReviewSessionHeader extends StatelessWidget {
  final int currentIndex;
  final int totalCards;
  final int masteredCount;

  const ReviewSessionHeader({
    super.key,
    required this.currentIndex,
    required this.totalCards,
    required this.masteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCards > 0 ? (currentIndex + 1) / totalCards : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kartička ${currentIndex + 1} z $totalCards',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.font(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ),
              if (masteredCount > 0)
                Text(
                  'umíš $masteredCount',
                  style: AppTheme.font(fontSize: 13.5, color: AppTheme.success, fontFeatures: AppTheme.tabularFigures),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppTheme.surfaceRaised,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
