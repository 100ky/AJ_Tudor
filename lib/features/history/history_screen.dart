import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../../services/agents/memory_manager_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final sessionsStream = repo.watchAllSessions();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Historie konverzací',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Session>>(
        stream: sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
                    child:
                        Icon(Icons.history, size: 40, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Zatím nemáš žádné lekce.',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.mutedTextColor(context), fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return SessionCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class SessionCard extends ConsumerWidget {
  final Session session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('d. MMMM yyyy, HH:mm', 'cs');
    final dateStr = dateFormat.format(session.startedAt);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showSessionDetail(context, ref),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
                if (session.fluencyScore != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.success.withValues(alpha: 0.12),
                          AppTheme.successLight.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${(session.fluencyScore! * 100).toInt()}% plynulost',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.topicSummary ?? 'Lekce angličtiny',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline, size: 15, color: AppTheme.error),
                const SizedBox(width: 4),
                Text('${session.totalErrors} chyb',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.mutedTextColor(context), fontSize: 13)),
                const Spacer(),
                Text(
                  'Zobrazit přepis',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
              ],
            ),
          ],
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

class _SessionDetailSheet extends ConsumerStatefulWidget {
  final Session session;
  final List<Transcript> transcripts;
  final List<ErrorLog> errors;

  const _SessionDetailSheet({
    required this.session,
    required this.transcripts,
    required this.errors,
  });

  @override
  ConsumerState<_SessionDetailSheet> createState() =>
      _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  bool _isAnalyzing = false;
  bool _isDeleting = false;

  void _analyzeSession() async {
    setState(() => _isAnalyzing = true);
    try {
      final memoryAgent = ref.read(memoryManagerAgentProvider);
      await memoryAgent.analyzeSession(widget.session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Analýza dokončena!'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při analýze: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Smazat lekci?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor(context),
            )),
        content: Text(
            'Opravdu chceš smazat tuto lekci z historie? Tato akce je nevratná.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.surfaceTextColor(context),
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zrušit',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.mutedTextColor(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession();
            },
            child: Text('Smazat',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _deleteSession() async {
    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final result = await repo.deleteSession(widget.session.id);

      if (mounted) {
        result.fold(
          (_) {
            ref.read(scenarioPlannerAgentProvider).planScenarios();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Lekce byla smazána. Paměť a scénáře se aktualizují.')),
            );
          },
          (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Chyba: ${failure.message}')),
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xF2100C22) : const Color(0xF5F6F4FC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1.0,
                ),
              ),
              boxShadow: AppTheme.glassShadows(context),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.session.topicSummary ?? 'Detail lekce',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      if (widget.session.topicSummary == null ||
                          widget.session.fluencyScore == null)
                        _isAnalyzing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : IconButton(
                                icon: Icon(Icons.analytics_outlined,
                                    color: AppTheme.primary),
                                tooltip: 'Analyzovat lekci manuálně',
                                onPressed: _analyzeSession,
                              ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: AppTheme.error),
                        tooltip: 'Smazat lekci',
                        onPressed: _isDeleting ? null : _confirmDelete,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: widget.transcripts.length,
                    itemBuilder: (context, index) {
                      final t = widget.transcripts[index];
                      final isUser = t.speaker == 'user';

                      // Bug fix: prázdný userSaid
                      final error = widget.errors
                          .where((e) =>
                              e.userSaid.isNotEmpty &&
                              t.content.contains(e.userSaid))
                          .firstOrNull;

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                  bottom: 4, top: 12),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                          0.78),
                              decoration: BoxDecoration(
                                gradient: isUser
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.primary,
                                          AppTheme.primaryDark,
                                        ],
                                      )
                                    : null,
                                color: isUser
                                    ? null
                                    : AppTheme.glassColor(context),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft:
                                      Radius.circular(isUser ? 20 : 4),
                                  bottomRight:
                                      Radius.circular(isUser ? 4 : 20),
                                ),
                                border: Border.all(
                                  color: isUser
                                      ? AppTheme.primaryLight
                                          .withValues(alpha: 0.35)
                                      : AppTheme.glassBorderColor(context),
                                  width: 1.0,
                                ),
                                boxShadow: isUser
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : AppTheme.glassShadowsLight(context),
                              ),
                              child: Text(
                                t.content,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isUser
                                      ? Colors.white
                                      : AppTheme.textColor(context),
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.78),
                                decoration: BoxDecoration(
                                  color: AppTheme.success
                                      .withValues(alpha: isDark ? 0.12 : 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 14,
                                            color: AppTheme.success),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            error.correctForm,
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      error.explanation,
                                      style:
                                          GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.mutedTextColor(context),
                                        height: 1.35,
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}
