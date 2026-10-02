import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../services/gemini/pronunciation_service.dart';

/// Barva skóre odpovědi v procentech (zelená / oranžová / červená).
Color answerScoreColor(int percent) => percent >= 85
    ? const Color(0xFF10B981)
    : (percent >= 65 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

/// Celkové skóre výslovnosti (zelená / oranžová / červená).
class PronunciationBadge extends StatelessWidget {
  final PronunciationAnalysis analysis;

  const PronunciationBadge(this.analysis, {super.key});

  @override
  Widget build(BuildContext context) {
    final score = (analysis.overallScore * 100).round();
    final scoreColor = answerScoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14, color: scoreColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Výslovnost: $score %',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hodnocení jednotlivých slov odpovědi (správně / nepřesně) s fonetickým tipem.
class WordAssessmentPills extends StatelessWidget {
  final PronunciationAnalysis analysis;

  const WordAssessmentPills(this.analysis, {super.key});

  @override
  Widget build(BuildContext context) {
    if (analysis.words.isEmpty) {
      return Text(
        analysis.transcribedText,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor(context),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: analysis.words.map((w) {
        final isAcc = w.isAccurate;
        final wordColor = isAcc ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        final bgColor = isAcc
            ? const Color(0xFF10B981).withValues(alpha: 0.16)
            : const Color(0xFFEF4444).withValues(alpha: 0.18);
        final borderColor = isAcc
            ? const Color(0xFF10B981).withValues(alpha: 0.35)
            : const Color(0xFFEF4444).withValues(alpha: 0.45);

        return Tooltip(
          message: (w.phoneticTip != null && w.phoneticTip!.isNotEmpty)
              ? w.phoneticTip!
              : (isAcc ? 'Správná výslovnost' : 'Nepřesná výslovnost'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAcc ? Icons.check_rounded : Icons.priority_high_rounded,
                  size: 13,
                  color: wordColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    w.recognizedWord.isNotEmpty ? w.recognizedWord : w.expectedWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: wordColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
