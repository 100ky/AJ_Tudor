import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/app_database.dart';
import '../../../services/gemini/pronunciation_service.dart';
import 'pronunciation_result.dart';

/// Rub kartičky: správné řešení, výslovnost, vysvětlení a původní věta.
class FlashcardBack extends StatelessWidget {
  final Flashcard card;
  final PronunciationAnalysis? lastPronunciation;
  final bool isPlayingTts;
  final VoidCallback onPlayAudio;
  final VoidCallback onDelete;
  final VoidCallback onFlip;

  const FlashcardBack({
    super.key,
    required this.card,
    required this.lastPronunciation,
    required this.isPlayingTts,
    required this.onPlayAudio,
    required this.onDelete,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastPronunciation = this.lastPronunciation;

    return GlassContainer(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
      color: AppTheme.success.withValues(alpha: isDark ? 0.12 : 0.05),
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      shadows: AppTheme.glassShadow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _correctAnswerLabel()),
                        const SizedBox(width: 8),
                        // Funkční tlačítko poslechu Gemini TTS
                        _ActionButton(
                          color: AppTheme.primary,
                          backgroundAlpha: 0.12,
                          tooltip: 'Přehrát rodilou výslovnost (Gemini TTS)',
                          onPressed: isPlayingTts ? null : onPlayAudio,
                          icon: isPlayingTts
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.volume_up_rounded,
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                        ),
                        const SizedBox(width: 6),
                        // Tlačítko pro trvalé smazání kartičky
                        _ActionButton(
                          color: AppTheme.error,
                          backgroundAlpha: 0.10,
                          tooltip: 'Smazat tuto kartičku',
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),

                    // Správná věta + srovnání s výslovností
                    Column(
                      children: [
                        Text(
                          card.backText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.primaryLight : AppTheme.primaryDark,
                            height: 1.3,
                          ),
                        ),
                        if (lastPronunciation != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Center(child: PronunciationBadge(lastPronunciation)),
                                const SizedBox(height: 8),
                                WordAssessmentPills(lastPronunciation),
                              ],
                            ),
                          ),
                        ],
                        // Nápověda a vysvětlení správného tvaru
                        if (card.explanation.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _explanation(context, isDark),
                        ],
                        if (card.sourceSentence != null &&
                            card.sourceSentence!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _sourceSentence(context, isDark),
                        ],
                      ],
                    ),

                    // Tlačítko otočení zpět
                    TextButton.icon(
                      onPressed: onFlip,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Otočit zpět na zadání'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _correctAnswerLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'SPRÁVNÉ ŘEŠENÍ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.success,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explanation(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NÁPOVĚDA A VYSVĚTLENÍ:',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.explanation,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppTheme.textColor(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceSentence(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 14, color: AppTheme.mutedTextColor(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Původně v konverzaci: "${card.sourceSentence}"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Malé čtvercové akční tlačítko v hlavičce rubu kartičky.
class _ActionButton extends StatelessWidget {
  final Color color;
  final double backgroundAlpha;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  const _ActionButton({
    required this.color,
    required this.backgroundAlpha,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
