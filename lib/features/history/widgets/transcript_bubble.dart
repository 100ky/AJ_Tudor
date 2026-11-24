import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../services/gemini/gemini_tts_service.dart';
import '../../conversation/widgets/interactive_tutor_text.dart';

/// Jedna replika přepisu lekce, u studenta případně s opravou chyby
/// a tlačítkem pro přidání do kartiček. Dlouhý stisk nahlásí problém u repliky.
class TranscriptBubble extends ConsumerStatefulWidget {
  final Transcript transcript;

  /// Chyba, kterou tutor v této replice opravil (párováno podle `userSaid`).
  final ErrorLog? error;

  /// Volá se po klepnutí na „Přidat do kartiček“.
  final VoidCallback onAddToFlashcards;

  /// Volá se po dlouhém stisku bubliny (nahlášení problému u této repliky).
  final VoidCallback? onLongPress;

  /// Problémy nahlášené u této repliky.
  final List<SessionIssue> issues;

  const TranscriptBubble({
    super.key,
    required this.transcript,
    required this.error,
    required this.onAddToFlashcards,
    this.onLongPress,
    this.issues = const [],
  });

  @override
  ConsumerState<TranscriptBubble> createState() => _TranscriptBubbleState();
}

class _TranscriptBubbleState extends ConsumerState<TranscriptBubble> {
  bool _isPlayingTts = false;

  Future<void> _playTts() async {
    if (_isPlayingTts) return;
    HapticFeedback.selectionClick();
    setState(() => _isPlayingTts = true);
    try {
      final success = await ref.read(geminiTtsServiceProvider).speak(widget.transcript.content);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepodařilo se přehrát výslovnost. Zkontrolujte připojení.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlayingTts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.transcript;
    final error = widget.error;
    final isUser = transcript.speaker == 'user';
    final hasCard = transcript.inFlashcard || (error != null && error.inFlashcard);
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: widget.onLongPress,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4, top: 12),
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.surfaceHigh : AppTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      transcript.content,
                      style: AppTheme.font(
                        color: AppTheme.textPrimary,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    InteractiveTutorText(
                      text: transcript.content,
                      style: AppTheme.font(
                        color: AppTheme.textPrimary,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  if (!isUser) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Přehrát zprávu',
                          onPressed: _isPlayingTts ? null : _playTts,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: _isPlayingTts
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: AppTheme.textSecondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.volume_up_rounded,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                        ),
                        if (widget.onLongPress != null) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: 'Nahlásit problém',
                            onPressed: widget.onLongPress,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (isUser && hasCard) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.style_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'V kartičkách',
                          style: AppTheme.font(
                            fontSize: 12,
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
          ),
          for (final issue in widget.issues) _issueNote(context, issue, maxWidth),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          error.correctForm,
                          style: AppTheme.font(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.explanation,
                    style: AppTheme.font(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasCard) _inFlashcardsBadge() else _addButton(),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _issueNote(BuildContext context, SessionIssue issue, double maxWidth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_rounded, size: 13, color: AppTheme.warning),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              issue.note,
              style: AppTheme.font(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inFlashcardsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.style_rounded,
            size: 12,
            color: AppTheme.success,
          ),
          const SizedBox(width: 4),
          Text(
            'V kartičkách',
            style: AppTheme.font(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    return InkWell(
      onTap: widget.onAddToFlashcards,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 14,
              color: AppTheme.textPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              'Přidat do kartiček',
              style: AppTheme.font(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
