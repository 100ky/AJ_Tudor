import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';

/// Jedna replika přepisu lekce, u studenta případně s opravou chyby
/// a tlačítkem pro přidání do kartiček.
class TranscriptBubble extends StatelessWidget {
  final Transcript transcript;

  /// Chyba, kterou tutor v této replice opravil (párováno podle `userSaid`).
  final ErrorLog? error;

  /// Volá se po klepnutí na „Přidat do kartiček“.
  final VoidCallback onAddToFlashcards;

  const TranscriptBubble({
    super.key,
    required this.transcript,
    required this.error,
    required this.onAddToFlashcards,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isUser = transcript.speaker == 'user';
    final error = this.error;
    final hasCard = transcript.inFlashcard || (error != null && error.inFlashcard);
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4, top: 12),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: maxWidth),
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
              color: isUser ? null : AppTheme.glassColor(context),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: Border.all(
                color: isUser
                    ? AppTheme.primaryLight.withValues(alpha: 0.35)
                    : AppTheme.glassBorderColor(context),
                width: 1.0,
              ),
              boxShadow: isUser
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : AppTheme.glassShadowsLight(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transcript.content,
                  style: GoogleFonts.plusJakartaSans(
                    color: isUser ? Colors.white : AppTheme.textColor(context),
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
                        style: GoogleFonts.plusJakartaSans(
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          error.correctForm,
                          style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.mutedTextColor(context),
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
            'V kartičkách 🃏',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
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
      onTap: onAddToFlashcards,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Přidat do kartiček',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
