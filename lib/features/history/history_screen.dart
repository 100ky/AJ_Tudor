import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/profile_provider.dart';
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

    String? durationStr;
    if (session.endedAt != null) {
      final diff = session.endedAt!.difference(session.startedAt);
      final minutes = diff.inMinutes;
      final seconds = diff.inSeconds.remainder(60);
      durationStr = minutes > 0 ? '$minutes min' : '$seconds s';
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showSessionDetail(context, ref),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          dateStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (durationStr != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 11,
                                  color: AppTheme.mutedTextColor(context)),
                              const SizedBox(width: 3),
                              Text(
                                durationStr,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.mutedTextColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (session.fluencyScore != null) ...[
                  const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.topicSummary ?? 'Lekce angličtiny',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (session.totalErrors == 0) ...[
                  Icon(Icons.check_circle_outline_rounded,
                      size: 15, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Text('Bez chyb 🎉',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ] else ...[
                  Icon(Icons.error_outline, size: 15, color: AppTheme.error),
                  const SizedBox(width: 4),
                  Text('${session.totalErrors} chyb',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.mutedTextColor(context),
                          fontSize: 13)),
                ],
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
  bool _isGeneratingCards = false;
  final _messageController = TextEditingController();
  bool _isSendingMessage = false;
  bool _isHeaderExpanded = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage(ScrollController scrollController) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    final client = ref.read(geminiBatchClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chybí Gemini API klíč! Nastavte ho v Profilu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSendingMessage = true);
    _messageController.clear();
    HapticFeedback.lightImpact();

    try {
      final repo = ref.read(sessionRepositoryProvider);

      // 1. Uložit zprávu studenta do transkriptů
      await repo.addTranscript(
        sessionId: widget.session.id,
        speaker: 'user',
        content: text,
      );

      // Posun dolů
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // 2. Načíst kontext z předchozích zpráv této lekce
      final allTranscripts = await repo.getTranscripts(widget.session.id);
      final recent = allTranscripts.length > 10
          ? allTranscripts.sublist(allTranscripts.length - 10)
          : allTranscripts;

      final conversationHistory = recent
          .map((t) =>
              '${t.speaker == 'user' ? 'Student' : 'Tudor'}: ${t.content}')
          .join('\n');

      final profile = ref.read(userProfileProvider).value;
      final targetLevel = profile?.targetLevel ?? 'B1';

      final prompt = '''Jsi AJ Tudor, přátelský a trpělivý rodilý učitel angličtiny pro Čechy.
Student s tebou právě pokračuje v textovém chatu z této výukové lekce (${widget.session.topicSummary ?? 'Lekce angličtiny'}).
Úroveň studenta: $targetLevel.

Předchozí kontext konverzace v této lekci:
$conversationHistory

Nová zpráva od studenta: "$text"

Instrukce pro odpověď:
1. Reaguj přirozeně a v angličtině na to, co student píše.
2. Pokud student udělal v angličtině gramatickou nebo slovní chybu, v závěru ho jemně a srozumitelně oprav (česky vysvětli správný tvar).
3. Pokud se student ptá česky na vysvětlení gramatiky, slovíček nebo překladu, vysvětli mu to srozumitelně česky a uveď anglický příklad.
4. Odpověď udržuj přiměřeně stručnou (2-4 věty) a na konci polož přesně JEDNU otázku v angličtině, aby konverzace plynula dál.
''';

      final reply = await client.sendMessage(prompt);

      // 3. Uložit odpověď tutora do transkriptů
      await repo.addTranscript(
        sessionId: widget.session.id,
        speaker: 'tutor',
        content: reply.trim(),
      );

      // Posun dolů po doručení odpovědi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent + 150,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při odesílání: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _generateCardsForSession() async {
    if (_isGeneratingCards) return;
    setState(() => _isGeneratingCards = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final res = await repo.generateFlashcardsFromErrors(
        sessionId: widget.session.id,
        limit: 15,
      );

      if (!mounted) return;

      res.fold(
        (count) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? 'Vytvořeno $count kartiček z chyb této lekce! 🎯'
                    : 'Všechny chyby z této lekce už máš v kartičkách! 👍',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: count > 0 ? AppTheme.success : AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba: ${failure.message}'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCards = false);
      }
    }
  }

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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isHeaderExpanded = !_isHeaderExpanded);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.session.topicSummary ?? 'Detail lekce',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor(context),
                                  ),
                                  maxLines: _isHeaderExpanded ? null : 1,
                                  overflow: _isHeaderExpanded
                                      ? null
                                      : TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_isHeaderExpanded &&
                                  widget.session.fluencyScore != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(widget.session.fluencyScore! * 100).toInt()}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                _isHeaderExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppTheme.mutedTextColor(context),
                              ),
                            ],
                          ),
                          if (_isHeaderExpanded) ...[
                            const SizedBox(height: 10),
                            Divider(
                              height: 1,
                              color: AppTheme.outlineLightColor(context),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.session.topicSummary == null ||
                                    widget.session.fluencyScore == null)
                                  _isAnalyzing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : TextButton.icon(
                                          icon: Icon(Icons.analytics_outlined,
                                              size: 16,
                                              color: AppTheme.primary),
                                          label: const Text('Analyzovat'),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            foregroundColor: AppTheme.primary,
                                            textStyle:
                                                GoogleFonts.plusJakartaSans(
                                                    fontSize: 12),
                                          ),
                                          onPressed: _analyzeSession,
                                        ),
                                TextButton.icon(
                                  icon: _isGeneratingCards
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primary,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded,
                                          size: 15),
                                  label: const Text('Kartičky z chyb'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppTheme.primary,
                                    textStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12),
                                  ),
                                  onPressed: _isGeneratingCards
                                      ? null
                                      : _generateCardsForSession,
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: AppTheme.error),
                                  tooltip: 'Smazat lekci',
                                  visualDensity: VisualDensity.compact,
                                  onPressed:
                                      _isDeleting ? null : _confirmDelete,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Transcript>>(
                    stream: ref
                        .watch(sessionRepositoryProvider)
                        .watchTranscripts(widget.session.id),
                    initialData: widget.transcripts,
                    builder: (context, transSnapshot) {
                      final currentTranscripts =
                          transSnapshot.data ?? widget.transcripts;

                      return StreamBuilder<List<ErrorLog>>(
                        stream: ref
                            .watch(sessionRepositoryProvider)
                            .watchErrorLogs(widget.session.id),
                        initialData: widget.errors,
                        builder: (context, errSnapshot) {
                          final currentErrors =
                              errSnapshot.data ?? widget.errors;

                          return ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: currentTranscripts.length,
                            itemBuilder: (context, index) {
                              final t = currentTranscripts[index];
                              final isUser = t.speaker == 'user';

                              // Párování chyb na základě userSaid
                              final error = currentErrors
                                  .where((e) =>
                                      e.userSaid.isNotEmpty &&
                                      t.content.contains(e.userSaid))
                                  .firstOrNull;

                              final hasCard = t.inFlashcard ||
                                  (error != null && error.inFlashcard);

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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
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
                                          if (isUser && hasCard) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.style_rounded,
                                                  size: 11,
                                                  color: Colors.white70,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'V kartičkách',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (error != null)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.78),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withValues(
                                              alpha: isDark ? 0.12 : 0.08),
                                          borderRadius:
                                              BorderRadius.circular(14),
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
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      color: AppTheme.success,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                color: AppTheme.mutedTextColor(
                                                    context),
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (hasCard)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.success
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: AppTheme.success
                                                            .withValues(
                                                                alpha: 0.35),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.style_rounded,
                                                          size: 12,
                                                          color:
                                                              AppTheme.success,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'V kartičkách 🃏',
                                                          style: GoogleFonts
                                                              .plusJakartaSans(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppTheme
                                                                .success,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  InkWell(
                                                    onTap: () async {
                                                      HapticFeedback
                                                          .lightImpact();
                                                      final repo = ref.read(
                                                          sessionRepositoryProvider);
                                                      final res = await repo
                                                          .createFlashcardFromTranscript(
                                                        transcriptId: t.id,
                                                        userSaid:
                                                            error.userSaid,
                                                        correctForm:
                                                            error.correctForm,
                                                        explanation:
                                                            error.explanation,
                                                        errorType:
                                                            error.errorType,
                                                        errorLogId: error.id,
                                                      );
                                                      if (context.mounted &&
                                                          res.isSuccess) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                                'Přidáno do kartiček: "${error.correctForm}" 🎯'),
                                                            backgroundColor:
                                                                AppTheme
                                                                    .success,
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            duration:
                                                                const Duration(
                                                                    seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 9,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary
                                                            .withValues(
                                                                alpha: 0.14),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                          color: AppTheme
                                                              .primary
                                                              .withValues(
                                                                  alpha: 0.4),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.add_rounded,
                                                            size: 14,
                                                            color: AppTheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'Přidat do kartiček',
                                                            style: GoogleFonts
                                                                .plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: AppTheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // ── Spodní lišta pro psaní zpráv do historie ───────────────
                _buildChatInputField(context, controller, isDark),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildChatInputField(
      BuildContext context, ScrollController scrollController, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF2100C22) : const Color(0xF5F6F4FC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppTheme.textColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Napiš Tudorovi zprávu...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.mutedTextColor(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendChatMessage(scrollController),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSendingMessage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                onPressed: _isSendingMessage
                    ? null
                    : () => _sendChatMessage(scrollController),
                tooltip: 'Odeslat zprávu',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
