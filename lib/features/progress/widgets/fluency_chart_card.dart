import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import 'collapsible_card.dart';

/// Graf vývoje plynulosti za posledních 10 hodnocených lekcí.
class FluencyChartCard extends StatelessWidget {
  final List<Session> sessions;
  final bool expanded;
  final VoidCallback onToggle;

  const FluencyChartCard({
    super.key,
    required this.sessions,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final validSessions = sessions
        .where((s) => s.fluencyScore != null)
        .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final recentSessions = validSessions.length > 10
        ? validSessions.sublist(validSessions.length - 10)
        : validSessions;

    if (recentSessions.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spots = [];
    for (int i = 0; i < recentSessions.length; i++) {
      spots.add(FlSpot(i.toDouble(), recentSessions[i].fluencyScore! * 100));
    }

    final latestScore = (recentSessions.last.fluencyScore! * 100).toInt();

    return CollapsibleCard(
      icon: Icons.show_chart_rounded,
      color: AppTheme.primary,
      title: 'Vývoj plynulosti',
      trailing: [CardBadge('$latestScore% naposledy', color: AppTheme.primary)],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.outline.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: AppTheme.onSurfaceMuted),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.onBackground,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toInt()}% plynulost',
                        GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (recentSessions.length - 1)
                  .toDouble()
                  .clamp(0.0, double.infinity),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppTheme.primary,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.3),
                        AppTheme.primary.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
