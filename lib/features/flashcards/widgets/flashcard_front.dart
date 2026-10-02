import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/gemini/pronunciation_service.dart';
import 'pronunciation_result.dart';

/// Líc kartičky: české zadání a mluvená odpověď s hodnocením výslovnosti.
///
/// Písemnou odpověď a „Nevím“ nabízí spodní lišta obrazovky.
class FlashcardFront extends StatelessWidget {
  /// České zadání (nebo text o probíhajícím překladu, pokud [isTranslating]).
  final String frontText;
  final bool isTranslating;
  final PronunciationAnalysis? lastPronunciation;
  final bool isEvaluatingSpeech;
  final bool isRecording;
  final double recordingVolume;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onFlip;

  const FlashcardFront({
    super.key,
    required this.frontText,
    required this.isTranslating,
    required this.lastPronunciation,
    required this.isEvaluatingSpeech,
    required this.isRecording,
    required this.recordingVolume,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastPronunciation = this.lastPronunciation;

    return GlassContainer(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
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
                    // Horní lišta líce
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (lastPronunciation != null)
                          PronunciationBadge(lastPronunciation)
                        else
                          const SizedBox(height: 20),
                      ],
                    ),

                    // Zadání otázky v češtině (žádná matoucí chybná angličtina!)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.translate_rounded,
                                  size: 13, color: AppTheme.mutedTextColor(context)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'PŘELOŽ DO ANGLIČTINY',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.mutedTextColor(context),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isTranslating)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.primary),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  frontText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.mutedTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            frontText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                              height: 1.35,
                            ),
                          ),
                      ],
                    ),

                    // Interaktivní mluvený trénink
                    Column(
                      children: [
                        if (isEvaluatingSpeech)
                          _evaluatingIndicator()
                        else if (isRecording)
                          _recordingButton()
                        else if (lastPronunciation != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                WordAssessmentPills(lastPronunciation),
                                if (lastPronunciation.feedback.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    lastPronunciation.feedback,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.mutedTextColor(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: onFlip,
                            icon: const Icon(Icons.flip_rounded, size: 16),
                            label: const Text('Zobrazit řešení'),
                          ),
                        ] else
                          _microphoneButton(context),
                      ],
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

  Widget _evaluatingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Hodnotím výslovnost...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingButton() {
    return GestureDetector(
      onTap: onStopRecording,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 62 + (recordingVolume * 20).clamp(0.0, 16.0),
            height: 62 + (recordingVolume * 20).clamp(0.0, 16.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withValues(
                      alpha: (0.4 + recordingVolume * 0.4).clamp(0.3, 0.8)),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
            ),
            child: Text(
              'Mluvte... Klepněte pro stop',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Výchozí stav: Kruhové tlačítko mikrofonu
  Widget _microphoneButton(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onStartRecording,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryLight, AppTheme.primaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Klepněte a odpovězte hlasem',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'nebo napište odpověď dole',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppTheme.mutedTextColor(context),
          ),
        ),
      ],
    );
  }
}
