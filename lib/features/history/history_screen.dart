import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final sessionsStream = repo.watchAllSessions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historie konverzací'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Session>>(
        stream: sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Zatím nemáš žádné lekce.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final Session session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('d. MMMM yyyy, HH:mm', 'cs');
    final dateStr = dateFormat.format(session.startedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showSessionDetail(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  if (session.fluencyScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(session.fluencyScore! * 100).toInt()}% plynulost',
                        style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.topicSummary ?? 'Lekce angličtiny',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text('${session.totalErrors} chyb', style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  const Text('Zobrazit přepis', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.blueAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetail(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sessionRepositoryProvider);
    final transcripts = await repo.getTranscripts(session.id);
    final errors = await repo.getErrorLogs(session.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionDetailSheet(
        session: session,
        transcripts: transcripts,
        errors: errors,
      ),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  final Session session;
  final List<Transcript> transcripts;
  final List<ErrorLog> errors;

  const _SessionDetailSheet({
    required this.session,
    required this.transcripts,
    required this.errors,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                session.topicSummary ?? 'Detail lekce',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: transcripts.length,
                itemBuilder: (context, index) {
                  final t = transcripts[index];
                  final isUser = t.speaker == 'user';
                  
                  // Najdeme chybu pro tento transcript, pokud existuje
                  final error = errors.where((e) => t.content.contains(e.userSaid)).firstOrNull;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 4, top: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isUser ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.white10),
                          ),
                          child: Text(t.content),
                        ),
                        if (error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(error.correctForm, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(error.explanation, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
