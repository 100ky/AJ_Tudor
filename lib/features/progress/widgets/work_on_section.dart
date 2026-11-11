import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/grouped_section.dart';
import '../../../data/models/progress_trends.dart';

/// Na čem pracovat: kolikrát se který druh chyby objevil v posledních lekcích a předtím.
class WorkOnSection extends StatelessWidget {
  final ProgressTrends trends;

  const WorkOnSection({super.key, required this.trends});

  /// „v 1 lekci“, „ve 3 lekcích“, „v 5 lekcích“.
  static String _inLessons(int n) {
    if (n == 1) return 'v 1 lekci';
    return '${n <= 4 ? 've' : 'v'} $n lekcích';
  }

  static String _inLast(int n) => n == 1 ? 'v poslední lekci' : 'v posledních $n lekcích';

  @override
  Widget build(BuildContext context) {
    final hasPrevious = trends.previousLessons > 0;
    final description = hasPrevious
        ? 'Kolikrát se chyba objevila ${_inLessons(trends.previousLessons)} předtím '
            'a ${_inLast(trends.recentLessons)}.'
        : 'Kolikrát se chyba objevila ${_inLast(trends.recentLessons)}. Srovnání přibude po dalších lekcích.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Na čem pracovat', description: description),
        GroupedSection(children: [for (final trend in trends.categories) _CategoryRow(trend)]),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryTrend trend;

  const _CategoryRow(this.trend);

  @override
  Widget build(BuildContext context) {
    final previous = trend.previousCount;
    final (verdict, color) = previous == null
        ? (null, AppTheme.textSecondary)
        : trend.improved
            ? ('ubývá', AppTheme.success)
            : trend.worse
                ? ('přibývá', AppTheme.error)
                : ('stejně', AppTheme.textSecondary);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(trend.category.label,
                  style: AppTheme.font(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            ),
            Text(
              previous == null ? '${trend.recentCount}×' : '$previous → ${trend.recentCount}',
              style: AppTheme.font(fontSize: 15, color: AppTheme.textSecondary, fontFeatures: AppTheme.tabularFigures),
            ),
            if (verdict != null)
              SizedBox(
                width: 72,
                child: Text(
                  verdict,
                  textAlign: TextAlign.right,
                  style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w600, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
