import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final userProfileStream = repo.watchUserProfile();
    final errorLogsStream = repo.watchAllErrorLogs();
    final sessionsStream = repo.watchAllSessions();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tvůj pokrok'),
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
                        if (profile?.memoryBriefing != null && profile!.memoryBriefing!.isNotEmpty) ...[
                          _buildMemoryCard(context, profile.memoryBriefing!),
                          const SizedBox(height: 24),
                        ],
                        _buildSectionTitle(context, 'Slovní zásoba'),
                        const SizedBox(height: 12),
                        _buildVocabularyChipCloud(context, profile?.vocabulary ?? '[]'),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Nedávné chyby (${errors.length})'),
                        const SizedBox(height: 12),
                        if (errors.isEmpty)
                          _buildEmptyStateCard(context, 'Zatím nemáš žádné zaznamenané chyby. Skvělá práce!')
                        else
                          ...errors.take(5).map((error) => _buildErrorTile(context, error)),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context, String message) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, UserProfile? profile, List<Session> sessions) {
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

    final activeDays = sessions.map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)).toSet().length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildGridCard(context, 'Lekce', '${profile?.totalSessions ?? 0}', Icons.play_lesson_rounded, Colors.blue),
        _buildGridCard(context, 'Čas', timeString, Icons.timer_rounded, Colors.orange),
        _buildGridCard(context, 'Slovíčka', '$vocabCount', Icons.abc_rounded, Colors.teal),
        _buildGridCard(context, 'Aktivní dny', '$activeDays', Icons.local_fire_department_rounded, Colors.redAccent),
      ],
    );
  }

  Widget _buildGridCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFluencyChart(BuildContext context, List<Session> sessions) {
    final validSessions = sessions
        .where((s) => s.fluencyScore != null)
        .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    
    final recentSessions = validSessions.length > 10 ? validSessions.sublist(validSessions.length - 10) : validSessions;

    if (recentSessions.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spots = [];
    for (int i = 0; i < recentSessions.length; i++) {
      spots.add(FlSpot(i.toDouble(), recentSessions[i].fluencyScore! * 100));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plynulost (poslední lekce)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (recentSessions.length - 1).toDouble().clamp(0.0, double.infinity),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Colors.blueAccent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withValues(alpha: 0.1),
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

  Widget _buildErrorDistributionChart(BuildContext context, List<ErrorLog> errors) {
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rozložení chyb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                            color: Colors.orange,
                            value: grammarCount.toDouble(),
                            title: '${((grammarCount/total)*100).toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (vocabCount > 0)
                          PieChartSectionData(
                            color: Colors.blue,
                            value: vocabCount.toDouble(),
                            title: '${((vocabCount/total)*100).toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (pronunCount > 0)
                          PieChartSectionData(
                            color: Colors.purple,
                            value: pronunCount.toDouble(),
                            title: '${((pronunCount/total)*100).toInt()}%',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text('Chyb', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Gramatika', Colors.orange),
                const SizedBox(width: 12),
                _buildLegendItem('Slovíčka', Colors.blue),
                const SizedBox(width: 12),
                _buildLegendItem('Výslovnost', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMemoryCard(BuildContext context, String briefing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.purpleAccent.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                'Co si tutor pamatuje',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(briefing, style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildVocabularyChipCloud(BuildContext context, String vocabJson) {
    try {
      final List<dynamic> words = jsonDecode(vocabJson);
      if (words.isEmpty) {
        return _buildEmptyStateCard(context, 'Zatím nemáš uložená žádná slovíčka.');
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: words.map((word) => Chip(
          label: Text(word.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
          backgroundColor: Colors.tealAccent.withValues(alpha: 0.1),
          side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        )).toList(),
      );
    } catch (e) {
      return const Text('Chyba načítání slovíček');
    }
  }

  Widget _buildErrorTile(BuildContext context, ErrorLog error) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getErrorColor(error.errorType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getErrorIcon(error.errorType),
              color: _getErrorColor(error.errorType),
            ),
          ),
          title: Text(
            error.userSaid,
            style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.redAccent, fontSize: 14),
          ),
          subtitle: Text(
            error.correctForm,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.explanation,
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  IconData _getErrorIcon(String type) {
    switch (type.toLowerCase()) {
      case 'grammar': return Icons.architecture;
      case 'vocabulary': return Icons.abc;
      case 'pronunciation': return Icons.record_voice_over;
      default: return Icons.error_outline;
    }
  }

  Color _getErrorColor(String type) {
    switch (type.toLowerCase()) {
      case 'grammar': return Colors.orange;
      case 'vocabulary': return Colors.blue;
      case 'pronunciation': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
