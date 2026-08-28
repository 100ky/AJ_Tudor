import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final userProfileStream = repo.watchUserProfile();
    final errorLogsStream = repo.watchAllErrorLogs();
    final sessionsStream = repo.watchAllSessions();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Tvůj pokrok',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileStream,
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;

          return StreamBuilder<List<ErrorLog>>(
            stream: errorLogsStream,
            builder: (context, errorsSnapshot) {
              final errors = errorsSnapshot.data ?? [];

              return StreamBuilder<List<Session>>(
                stream: sessionsStream,
                builder: (context, sessionsSnapshot) {
                  final sessions = sessionsSnapshot.data ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryGrid(context, profile, sessions),
                        const SizedBox(height: 24),
                        if (sessions.isNotEmpty) ...[
                          _buildFluencyChart(context, sessions),
                          const SizedBox(height: 24),
                        ],
                        if (errors.isNotEmpty) ...[
                          _buildErrorDistributionChart(context, errors),
                          const SizedBox(height: 24),
                        ],
                        if (profile?.memoryBriefing != null &&
                            profile!.memoryBriefing!.isNotEmpty) ...[
                          _buildMemoryCard(context, profile.memoryBriefing!),
                          const SizedBox(height: 24),
                        ],
                        _buildSectionTitle('Slovní zásoba'),
                        const SizedBox(height: 12),
                        _buildVocabularyChipCloud(
                            context, profile?.vocabulary ?? '[]'),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Nedávné chyby (${errors.length})'),
                        const SizedBox(height: 12),
                        if (errors.isEmpty)
                          _buildEmptyStateCard(context,
                              'Zatím nemáš žádné zaznamenané chyby. Skvělá práce!')
                        else
                          ...errors
                              .take(5)
                              .map((error) => _buildErrorTile(context, error)),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.onSurfaceMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context, String message) {
    return GlassContainer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurfaceMuted,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(
      BuildContext context, UserProfile? profile, List<Session> sessions) {
    Duration totalDuration = Duration.zero;
    for (var s in sessions) {
      if (s.endedAt != null) {
        totalDuration += s.endedAt!.difference(s.startedAt);
      }
    }
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final timeString = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    int vocabCount = 0;
    try {
      final List<dynamic> words = jsonDecode(profile?.vocabulary ?? '[]');
      vocabCount = words.length;
    } catch (_) {}

    final activeDays = sessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildGridCard('Lekce', '${profile?.totalSessions ?? 0}',
            Icons.play_lesson_rounded, AppTheme.primary),
        _buildGridCard('Čas', timeString, Icons.timer_rounded, AppTheme.accent),
        _buildGridCard('Slovíčka', '$vocabCount', Icons.abc_rounded,
            AppTheme.success),
        _buildGridCard('Aktivní dny', '$activeDays',
            Icons.local_fire_department_rounded, AppTheme.error),
      ],
    );
  }

  Widget _buildGridCard(
      String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluencyChart(BuildContext context, List<Session> sessions) {
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

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vývoj plynulosti',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
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
                  bottomTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      ),
    );
  }

  Widget _buildErrorDistributionChart(
      BuildContext context, List<ErrorLog> errors) {
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

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rozložení chyb',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: [
                      if (grammarCount > 0)
                        PieChartSectionData(
                          color: AppTheme.grammar,
                          value: grammarCount.toDouble(),
                          title: '${((grammarCount / total) * 100).toInt()}%',
                          radius: 30,
                          titleStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      if (vocabCount > 0)
                        PieChartSectionData(
                          color: AppTheme.vocabulary,
                          value: vocabCount.toDouble(),
                          title: '${((vocabCount / total) * 100).toInt()}%',
                          radius: 30,
                          titleStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      if (pronunCount > 0)
                        PieChartSectionData(
                          color: AppTheme.pronunciation,
                          value: pronunCount.toDouble(),
                          title: '${((pronunCount / total) * 100).toInt()}%',
                          radius: 30,
                          titleStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      Text(
                        'Chyb',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Gramatika', AppTheme.grammar),
              const SizedBox(width: 16),
              _buildLegendItem('Slovíčka', AppTheme.vocabulary),
              const SizedBox(width: 16),
              _buildLegendItem('Výslovnost', AppTheme.pronunciation),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
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
              fontSize: 12, color: AppTheme.onSurface, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMemoryCard(BuildContext context, String briefing) {
    return GlassContainer(
      color: AppTheme.primary.withValues(alpha: 0.05),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.psychology, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Co si tutor pamatuje',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: GoogleFonts.plusJakartaSans(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: AppTheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyChipCloud(BuildContext context, String vocabJson) {
    try {
      final List<dynamic> words = jsonDecode(vocabJson);
      if (words.isEmpty) {
        return _buildEmptyStateCard(
            context, 'Zatím nemáš uložená žádná slovíčka.');
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: words
            .map((word) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.glassLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Text(
                    word.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppTheme.onBackground,
                    ),
                  ),
                ))
            .toList(),
      );
    } catch (e) {
      return Text('Chyba načítání slovíček',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.error));
    }
  }

  Widget _buildErrorTile(BuildContext context, ErrorLog error) {
    final color = AppTheme.errorTypeColor(error.errorType);
    final icon = AppTheme.errorTypeIcon(error.errorType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: color,
          collapsedIconColor: AppTheme.onSurfaceMuted,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            error.userSaid,
            style: GoogleFonts.plusJakartaSans(
              decoration: TextDecoration.lineThrough,
              color: AppTheme.error,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            error.correctForm,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.explanation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
