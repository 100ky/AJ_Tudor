import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';

/// Spodní lišta líce kartičky: napsaná odpověď nebo přiznání „Nevím“.
///
/// Kartičku nejde otočit bez pokusu o odpověď (hlasem, písemně nebo „Nevím“),
/// aby se nedala ohodnotit bez zkoušení.
class AnswerInputBar extends StatefulWidget {
  /// False během nahrávání a hodnocení mluvené odpovědi.
  final bool enabled;
  final ValueChanged<String> onSubmit;
  final VoidCallback onGiveUp;

  const AnswerInputBar({
    super.key,
    required this.enabled,
    required this.onSubmit,
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
    if (text.isEmpty || !widget.enabled) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.enabled && _textController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: widget.enabled,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                style: GoogleFonts.hankenGrotesk(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Napiš odpověď anglicky…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: canSubmit ? _submit : null,
              tooltip: 'Odeslat odpověď',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: AppTheme.background,
                disabledBackgroundColor: AppTheme.surfaceRaised,
                minimumSize: const Size(52, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: widget.enabled ? widget.onGiveUp : null,
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: Text(
            'Nevím – ukázat řešení',
            style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
