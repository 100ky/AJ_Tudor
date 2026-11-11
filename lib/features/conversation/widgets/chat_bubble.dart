import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import 'interactive_tutor_text.dart';

/// Moderní znovupoužitelná bublina zprávy pro chat i hlasové přepisy.
///
/// Podporuje:
/// - Plný gradient pro zprávy uživatele s bílým písmem
/// - Frosted glass styl s Markdown formátováním pro zprávy tutora (adaptivní pro Light i Dark mode)
/// - Dlouhé stisknutí pro zkopírování do schránky s haptickou odezvou
/// - Avatar tutora
class ChatBubble extends StatelessWidget {
  /// Text zprávy
  final String text;

  /// Určuje, zda je odesílatelem uživatel (true) nebo AI tutor (false)
  final bool isUser;

  /// Volitelný callback při kliknutí na celou bublinu
  final VoidCallback? onTap;

  /// Maximální šířka bubliny v poměru k šířce obrazovky (výchozí: 0.80)
  final double maxWidthFraction;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onTap,
    this.maxWidthFraction = 0.80,
  });

  void _copyToClipboard(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Zpráva zkopírována do schránky',
              style: GoogleFonts.hankenGrotesk(fontSize: 13),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * maxWidthFraction;

    final tutorBgColor = AppTheme.glassColor(context);
        final tutorTextColor = AppTheme.textColor(context);
    final tutorStrongColor =
        isDark ? AppTheme.primaryLight : AppTheme.primaryDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [

            // Samotná bublina
            Flexible(
              child: GestureDetector(
                onLongPress: isUser ? () => _copyToClipboard(context) : null,
                onTap: isUser ? onTap : null,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.surfaceHigh : tutorBgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 18 : 6),
                      topRight: Radius.circular(isUser ? 6 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                                      ),
                  child: isUser
                      ? Text(
                          text,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : InteractiveTutorText(
                          text: text,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            color: tutorTextColor,
                            height: 1.45,
                          ),
                          strongStyle: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tutorStrongColor,
                          ),
                          emStyle: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: tutorTextColor,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

