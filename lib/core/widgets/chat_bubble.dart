import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

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
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
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
    final tutorBorderColor = AppTheme.glassBorderColor(context);
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
            // Avatar tutora
            if (!isUser) ...[
              Container(
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],

            // Samotná bublina
            Flexible(
              child: GestureDetector(
                onLongPress: () => _copyToClipboard(context),
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primary,
                              AppTheme.primaryDark,
                            ],
                          )
                        : null,
                    color: isUser ? null : tutorBgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 20),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppTheme.primaryLight.withValues(alpha: 0.4)
                          : tutorBorderColor,
                      width: 1.0,
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : AppTheme.glassShadowsLight(context),
                  ),
                  child: isUser
                      ? Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : MarkdownBody(
                          data: text,
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: tutorTextColor,
                              height: 1.45,
                            ),
                            strong: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tutorStrongColor,
                            ),
                            em: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: tutorTextColor,
                            ),
                            listBullet: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: AppTheme.primary,
                            ),
                            code: GoogleFonts.firaCode(
                              fontSize: 13,
                              color: tutorStrongColor,
                              backgroundColor: AppTheme.primary
                                  .withValues(alpha: isDark ? 0.2 : 0.08),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: isDark ? 0.15 : 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(
                                  color: AppTheme.primary,
                                  width: 3,
                                ),
                              ),
                            ),
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

