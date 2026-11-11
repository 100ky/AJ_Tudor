import 'package:flutter/material.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final lastPronunciation = this.lastPronunciation;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Přelož do angličtiny',
                            style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                          ),
                        ),
                        if (lastPronunciation != null) PronunciationBadge(lastPronunciation),
                      ],
                    ),

                    // Zadání otázky v češtině (žádná matoucí chybná angličtina!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: isTranslating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    frontText,
                                    style: AppTheme.font(fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              frontText,
                              textAlign: TextAlign.center,
                              style: AppTheme.font(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                            ),
                    ),

                    // Mluvená odpověď
                    Column(
                      children: [
                        if (isEvaluatingSpeech)
                          _evaluatingIndicator()
                        else if (isRecording)
                          _recordingButton()
                        else if (lastPronunciation != null) ...[
                          WordAssessmentPills(lastPronunciation),
                          if (lastPronunciation.feedback.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              lastPronunciation.feedback,
                              textAlign: TextAlign.center,
                              style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                            ),
                          ],
                        ] else
                          _microphoneButton(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('Hodnotím výslovnost...', style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _recordingButton() {
    final grow = (recordingVolume * 20).clamp(0.0, 16.0);
    return Semantics(
      button: true,
      label: 'Ukončit nahrávání',
      child: GestureDetector(
        onTap: onStopRecording,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 62 + grow,
                  height: 62 + grow,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.danger),
                  child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Mluv… klepnutím nahrávání ukončíš', style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// Výchozí stav: bílé kulaté tlačítko mikrofonu.
  Widget _microphoneButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Odpovědět hlasem',
          child: GestureDetector(
            onTap: onStartRecording,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.textPrimary),
              child: const Icon(Icons.mic_rounded, color: AppTheme.background, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Klepni a odpověz hlasem', style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text('nebo napiš odpověď dole', style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}
