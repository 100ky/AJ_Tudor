import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('Tvůj pokrok'),
        centerTitle: true,
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
                  
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatsCard(profile),
                      const SizedBox(height: 24),
                      if (sessions.isNotEmpty) ...[
                        _buildFluencyTrend(context, sessions),
                        const SizedBox(height: 24),
                      ],
                      if (profile?.memoryBriefing != null) ...[
                        _buildMemoryCard(profile!.memoryBriefing!),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Slovní zásoba',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildVocabularyChipCloud(profile?.vocabulary ?? '[]'),
                      const SizedBox(height: 24),
                      Text(
                        'Nedávné chyby (${errors.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (errors.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Zatím nemáš žádné zaznamenané chyby. Skvělá práce!'),
                          ),
                        )
                      else
                        ...errors.map((error) => _buildErrorTile(context, error)),
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

  Widget _buildFluencyTrend(BuildContext context, List<Session> sessions) {
    // Vezmeme posledních 7 sessions, které mají skóre
    final validSessions = sessions
        .where((s) => s.fluencyScore != null)
        .take(7)
        .toList()
        .reversed
        .toList();
        
    if (validSessions.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plynulost (poslední lekce)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: validSessions.map((s) {
                  final score = s.fluencyScore! * 100;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: (score / 2).clamp(5.0, 50.0),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${score.toInt()}%', style: const TextStyle(fontSize: 10)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyChipCloud(String vocabJson) {
    try {
      final List<dynamic> words = jsonDecode(vocabJson);
      if (words.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Zatím nemáš uložená žádná slovíčka.'),
          ),
        );
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: words.map((word) => Chip(
          label: Text(word.toString()),
          backgroundColor: Colors.tealAccent.withValues(alpha: 0.1),
          side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3)),
        )).toList(),
      );
    } catch (e) {
      return const Text('Chyba načítání slovíček');
    }
  }

  Widget _buildStatsCard(UserProfile? profile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Lekce', '${profile?.totalSessions ?? 0}'),
                _buildStatItem('Úroveň', profile?.targetLevel ?? 'B1'),
                _buildStatItem('Jazyk', profile?.nativeLanguage.toUpperCase() ?? 'CS'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMemoryCard(String briefing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Co si tutor pamatuje',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(briefing, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildErrorTile(BuildContext context, ErrorLog error) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          _getErrorIcon(error.errorType),
          color: _getErrorColor(error.errorType),
        ),
        title: Text(
          error.userSaid,
          style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.redAccent),
        ),
        subtitle: Text(
          error.correctForm,
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error.explanation,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
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
