import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';

/// Spodní lišta líce kartičky: napsaná nebo mluvená odpověď a přiznání „Nevím“.
///
/// Kartičku nejde otočit bez pokusu o odpověď (hlasem, písemně nebo „Nevím“),
/// aby se nedala ohodnotit bez zkoušení. Dokud je textové pole prázdné, akční
/// tlačítko napravo spouští hlasový vstup; po napsání textu se přepne na odeslání.
class AnswerInputBar extends StatefulWidget {
  /// False během nahrávání a hodnocení mluvené odpovědi.
  final bool enabled;
  final bool isRecording;
  final bool isEvaluatingSpeech;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback onGiveUp;

  const AnswerInputBar({
    super.key,
    required this.enabled,
    this.isRecording = false,
    this.isEvaluatingSpeech = false,
    required this.onSubmit,
    this.onStartRecording,
    this.onStopRecording,
    required this.onGiveUp,
  });

  @override
  State<AnswerInputBar> createState() => _AnswerInputBarState();
}

class _AnswerInputBarState extends State<AnswerInputBar> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isRecording || widget.isEvaluatingSpeech) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;
    final canInput = widget.enabled && !widget.isRecording && !widget.isEvaluatingSpeech;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: widget.isRecording
                  ? Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.graphic_eq_rounded, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Nahrávám odpověď…',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      enabled: canInput,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                      style: GoogleFonts.hankenGrotesk(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Napiš nebo řekni anglicky…',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
            ),
            if (!widget.isRecording) ...[
              const SizedBox(width: 8),
              _actionButton(canInput: canInput, hasText: hasText),
            ],
          ],
        ),
        TextButton.icon(
          onPressed: canInput ? widget.onGiveUp : null,
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: Text(
            'Nevím – ukázat řešení',
            style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({required bool canInput, required bool hasText}) {
    final VoidCallback? onPressed;
    final String tooltip;
    final Color background;
    final Color foreground;
    final IconData icon;

    if (hasText) {
      onPressed = canInput ? _submit : null;
      tooltip = 'Odeslat odpověď';
      background = AppTheme.textPrimary;
      foreground = AppTheme.background;
      icon = Icons.send_rounded;
    } else if (widget.isRecording) {
      onPressed = widget.onStopRecording;
      tooltip = 'Ukončit nahrávání';
      background = AppTheme.danger;
      foreground = Colors.white;
      icon = Icons.stop_rounded;
    } else {
      onPressed = canInput ? widget.onStartRecording : null;
      tooltip = 'Odpovědět hlasem';
      background = AppTheme.textPrimary;
      foreground = AppTheme.background;
      icon = Icons.mic_rounded;
    }

    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: AppTheme.surfaceRaised,
        minimumSize: const Size(52, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: hasText ? 20 : 22),
    );
  }
}
