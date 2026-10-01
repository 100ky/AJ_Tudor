import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/data_providers.dart';
import '../../../data/database/app_database.dart';
import '../session_detail_controller.dart';
import 'chat_input_bar.dart';
import 'delete_session_dialog.dart';
import 'session_detail_header.dart';
import 'transcript_bubble.dart';

/// Detail lekce: přepis s opravami chyb a textové pokračování konverzace.
class SessionDetailSheet extends ConsumerStatefulWidget {
  final Session session;

  /// Přepis a chyby načtené před otevřením (zobrazí se, než naběhnou živá data).
  final List<Transcript> transcripts;
  final List<ErrorLog> errors;

  const SessionDetailSheet({
    super.key,
    required this.session,
    required this.transcripts,
    required this.errors,
  });

  @override
  ConsumerState<SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<SessionDetailSheet> {
  bool _isAnalyzing = false;
  bool _isGeneratingCards = false;
  final _messageController = TextEditingController();
  bool _isSendingMessage = false;
  bool _isHeaderExpanded = false;

  SessionDetailController get _controller => ref.read(sessionDetailControllerProvider);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage(ScrollController scrollController) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    if (!_controller.canChat) {
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
      await _controller.sendFollowUp(
        widget.session,
        text,
        onStudentMessageSaved: () => _scrollToEnd(scrollController, 100),
      );
      // Posun dolů po doručení odpovědi
      _scrollToEnd(scrollController, 150);
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

  void _scrollToEnd(ScrollController scrollController, double overshoot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + overshoot,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateCardsForSession() async {
    if (_isGeneratingCards) return;
    setState(() => _isGeneratingCards = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await _controller.generateCards(widget.session.id);

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
      await _controller.analyze(widget.session.id);
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

  Future<void> _addToFlashcards(Transcript transcript, ErrorLog error) async {
    HapticFeedback.lightImpact();
    final res = await _controller.addErrorToFlashcards(transcript, error);
    if (mounted && res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Přidáno do kartiček: "${error.correctForm}" 🎯'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmDelete() {
    confirmAndDeleteSession(
      context,
      ref,
      widget.session,
      onDeleted: () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final transcripts =
        ref.watch(sessionTranscriptsProvider(widget.session.id)).value ??
            widget.transcripts;
    final errors = ref.watch(sessionErrorLogsProvider(widget.session.id)).value ??
        widget.errors;

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
                    child: SessionDetailHeader(
                      session: widget.session,
                      expanded: _isHeaderExpanded,
                      onToggle: () =>
                          setState(() => _isHeaderExpanded = !_isHeaderExpanded),
                      isAnalyzing: _isAnalyzing,
                      isGeneratingCards: _isGeneratingCards,
                      onAnalyze: _analyzeSession,
                      onGenerateCards: _generateCardsForSession,
                      onDelete: _confirmDelete,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: transcripts.length,
                      itemBuilder: (context, index) {
                        final t = transcripts[index];

                        // Párování chyb na základě userSaid
                        final error = errors
                            .where((e) =>
                                e.userSaid.isNotEmpty &&
                                t.content.contains(e.userSaid))
                            .firstOrNull;

                        return TranscriptBubble(
                          transcript: t,
                          error: error,
                          onAddToFlashcards: () => _addToFlashcards(t, error!),
                        );
                      },
                    ),
                  ),

                  // ── Spodní lišta pro psaní zpráv do historie ───────────────
                  ChatInputBar(
                    controller: _messageController,
                    isSending: _isSendingMessage,
                    onSend: () => _sendChatMessage(controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
