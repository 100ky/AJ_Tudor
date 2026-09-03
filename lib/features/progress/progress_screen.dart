import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../../services/agents/topic_preparation_agent.dart';
import '../../data/repositories/session_repository.dart';
import '../history/history_screen.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
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
            color: AppTheme.textColor(context),
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

                  return Column(
                    children: [
                      // ── Přepínač: Přehled vs Historie ──────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(
                              value: 0,
                              icon: Icon(Icons.analytics_outlined, size: 16),
                              label: Text('Přehled'),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              icon: Icon(Icons.psychology_outlined, size: 16),
                              label: Text('O mně'),
                            ),
                            ButtonSegment<int>(
                              value: 2,
                              icon: Icon(Icons.history_rounded, size: 16),
                              label: Text('Historie'),
                            ),
                          ],
                          selected: {_selectedTabIndex},
                          onSelectionChanged: (set) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedTabIndex = set.first;
                            });
                          },
                        ),
                      ),

                      // ── Obsah podle vybrané záložky ────────────────────────
                      Expanded(
                        child: _selectedTabIndex == 0
                            ? _buildOverviewTab(context, profile, sessions, errors)
                            : _selectedTabIndex == 1
                                ? _buildAboutMeTab(context, profile)
                                : _buildHistoryTab(context, sessions),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, UserProfile? profile,
      List<Session> sessions, List<ErrorLog> errors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
          _buildSectionTitle('Slovní zásoba', context),
          const SizedBox(height: 12),
          _buildVocabularyChipCloud(
              context, profile?.vocabulary ?? '[]'),
          const SizedBox(height: 24),
          _buildSectionTitle('Nedávné chyby (${errors.length})', context),
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
  }

  Widget _buildHistoryTab(BuildContext context, List<Session> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.history_rounded,
                    size: 38, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Zatím nemáš žádné lekce',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Spusť svou první hlasovou lekci v záložce Hlas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return SessionCard(session: session);
      },
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedTextColor(context),
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
        _buildGridCard(context, 'Lekce', '${profile?.totalSessions ?? 0}',
            Icons.play_lesson_rounded, AppTheme.primary),
        _buildGridCard(context, 'Čas', timeString, Icons.timer_rounded, AppTheme.accent),
        _buildGridCard(context, 'Slovíčka', '$vocabCount', Icons.abc_rounded,
            AppTheme.success),
        _buildGridCard(context, 'Aktivní dny', '$activeDays',
            Icons.local_fire_department_rounded, AppTheme.error),
      ],
    );
  }

  Widget _buildGridCard(BuildContext context,
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
                  color: AppTheme.mutedTextColor(context),
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
              color: AppTheme.textColor(context),
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
              color: AppTheme.textColor(context),
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
              color: AppTheme.textColor(context),
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
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      Text(
                        'Chyb',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.mutedTextColor(context),
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
              _buildLegendItem(context, 'Gramatika', AppTheme.grammar),
              const SizedBox(width: 16),
              _buildLegendItem(context, 'Slovíčka', AppTheme.vocabulary),
              const SizedBox(width: 16),
              _buildLegendItem(context, 'Výslovnost', AppTheme.pronunciation),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String title, Color color) {
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
              color: AppTheme.surfaceTextColor(context),
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
                    color: AppTheme.glassLightColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.glassBorderColor(context),
                    ),
                  ),
                  child: Text(
                    word.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppTheme.textColor(context),
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
        color: AppTheme.glassColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.glassBorderColor(context),
        ),
        boxShadow: AppTheme.glassShadowsLight(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          iconColor: color,
          collapsedIconColor: AppTheme.mutedTextColor(context),
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
                  color: AppTheme.backgroundSecondaryColor(context),
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
                          color: AppTheme.surfaceTextColor(context),
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
    ),
  );
}

  // ── Záložka "O mně" (Znalosti tutora o studentovi) ──────────────────────────
  Widget _buildAboutMeTab(BuildContext context, UserProfile? profile) {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final repo = ref.watch(sessionRepositoryProvider);

    List<String> facts = [];
    if (profile?.userFacts != null && profile!.userFacts.isNotEmpty) {
      try {
        final List<dynamic> raw = jsonDecode(profile.userFacts);
        facts = raw.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Karta: Informace o profilové paměti ───────────────────────────────
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.psychology_rounded,
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Co si o tobě Tudor pamatuje',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tudor si tyto informace automaticky doplňuje po každé hlasové lekci. Díky nim se neptá dokola na stejné věci a konverzace navazuje na tvůj život.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppTheme.mutedTextColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Karta: Připravené téma od Startup Agenta ─────────────────────────
          _buildSectionTitle('Připravené téma do hlasu', context),
          const SizedBox(height: 8),
          _buildPreparedTopicCard(context, topicState),

          const SizedBox(height: 24),

          // ── Sekce: Osobní fakta ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Fakta o mně (${facts.length})', context),
              TextButton.icon(
                onPressed: () => _showAddFactDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Přidat fakt'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (facts.isEmpty)
            _buildEmptyStateCard(
              context,
              'Zatím zde nejsou žádné záznamy.\nTudor si z vašich rozhovorů automaticky zapamatuje záliby, práci, mazlíčky i zážitky, nebo můžete přidat informaci tlačítkem výše.',
            )
          else
            ...facts.map((fact) => _buildFactTile(context, fact, repo)),
        ],
      ),
    );
  }

  Widget _buildPreparedTopicCard(
      BuildContext context, TopicPreparationState topicState) {
    if (topicState.isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Agent připravuje nové originální téma z historie...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final topic = topicState.topic;
    if (topic == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppTheme.onSurfaceMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Zatím není připraveno žádné téma.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Připravit téma',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                ref
                    .read(topicPreparationAgentProvider.notifier)
                    .prepareTopic(force: true);
              },
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primary.withValues(alpha: 0.05),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  topic.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Vyměnit téma',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: AppTheme.primary,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(topicPreparationAgentProvider.notifier)
                      .prepareTopic(force: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondaryColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.openerEn,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textColor(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (topic.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              topic.rationale,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactTile(
      BuildContext context, String fact, SessionRepository repo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.glassColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fact,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 16, color: AppTheme.onSurfaceMuted),
            visualDensity: VisualDensity.compact,
            tooltip: 'Smazat fakt',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await repo.removeUserFact(fact);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fakt byl odstraněn z paměti.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddFactDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondaryColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Přidat informaci o mně',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppTheme.textColor(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zadej fakt, který by si měl Tudor pamatovat (např. o zálibách, mazlíčcích, práci nebo životě):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Např. Mám psa labradora jménem Rex',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceMuted,
                ),
                filled: true,
                fillColor: AppTheme.glassLightColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppTheme.glassBorderColor(context)),
                ),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Zrušit',
              style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogCtx);
                await ref.read(sessionRepositoryProvider).addUserFact(text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Informace byla úspěšně přidána! ✅')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Uložit',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
