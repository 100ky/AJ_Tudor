import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import 'collapsible_card.dart';

/// Koláčový graf rozložení chyb podle typu (gramatika, slovíčka, výslovnost).
class ErrorDistributionCard extends StatelessWidget {
  final List<ErrorLog> errors;
  final bool expanded;
  final VoidCallback onToggle;

  const ErrorDistributionCard({
    super.key,
    required this.errors,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    int grammarCount = 0;
    int vocabCount = 0;
    int pronunCount = 0;

    for (var error in errors) {
      if (error.errorType.toLowerCase() == 'grammar') {
        grammarCount++;
      } else if (error.errorType.toLowerCase() == 'vocabulary') {
        vocabCount++;
      } else if (error.errorType.toLowerCase() == 'pronunciation') {
        pronunCount++;
      }
    }

    final total = errors.length;

    return CollapsibleCard(
      icon: Icons.pie_chart_outline_rounded,
      color: AppTheme.error,
      title: 'Rozložení chyb',
      trailing: [CardBadge('Celkem $total chyb', color: AppTheme.error)],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 55,
                  sections: [
                    if (grammarCount > 0)
                      _section(grammarCount, total, AppTheme.grammar),
                    if (vocabCount > 0)
                      _section(vocabCount, total, AppTheme.vocabulary),
                    if (pronunCount > 0)
                      _section(pronunCount, total, AppTheme.pronunciation),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    Text(
                      'Chyb',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem('Gramatika', AppTheme.grammar),
            const SizedBox(width: 16),
            _LegendItem('Slovíčka', AppTheme.vocabulary),
            const SizedBox(width: 16),
            _LegendItem('Výslovnost', AppTheme.pronunciation),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _section(int count, int total, Color color) {
    return PieChartSectionData(
      color: color,
      value: count.toDouble(),
      title: '${((count / total) * 100).toInt()}%',
      radius: 28,
      titleStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String title;
  final Color color;

  const _LegendItem(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.surfaceTextColor(context),
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
