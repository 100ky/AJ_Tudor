import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/app_database.dart';
import '../../../services/gemini/pronunciation_service.dart';
import '../sentence_highlight.dart';
import '../typed_answer.dart';
import 'pronunciation_result.dart';

/// Rub kartičky: správné řešení, odpověď studenta, vysvětlení a původní věta.
class FlashcardBack extends StatelessWidget {
  final Flashcard card;

  /// Vysvětlení výrazu (z CardExplanationResolver); null = blok se nezobrazí.
  final String? explanation;
  final PronunciationAnalysis? lastPronunciation;
  final TypedAnswer? typedAnswer;
  final bool isPlayingTts;
  final VoidCallback onPlayAudio;
  final VoidCallback onDelete;
  final VoidCallback onFlip;

  const FlashcardBack({
    super.key,
    required this.card,
    this.explanation,
    required this.lastPronunciation,
    this.typedAnswer,
    required this.isPlayingTts,
    required this.onPlayAudio,
    required this.onDelete,
    required this.onFlip,
  });

  static final _label = AppTheme.font(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.textTertiary);

  @override
  Widget build(BuildContext context) {
    final lastPronunciation = this.lastPronunciation;
    final typedAnswer = this.typedAnswer;
    final explanation = this.explanation;
    final hasSource = card.sourceSentence != null && card.sourceSentence!.trim().isNotEmpty;

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(22, 14, 10, 14),
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
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Správné řešení', style: _label)),
                        IconButton(
                          tooltip: 'Přehrát rodilou výslovnost (Gemini TTS)',
                          onPressed: isPlayingTts ? null : onPlayAudio,
                          style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceRaised),
                          icon: isPlayingTts
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.volume_up_rounded, size: 22, color: AppTheme.textPrimary),
                        ),
                        IconButton(
                          tooltip: 'Smazat tuto kartičku',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.backText,
                            style: AppTheme.font(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (lastPronunciation != null) ...[
                            const SizedBox(height: 16),
                            PronunciationBadge(lastPronunciation),
                            const SizedBox(height: 8),
                            WordAssessmentPills(lastPronunciation),
                          ],
                          if (typedAnswer != null) ...[
                            const SizedBox(height: 18),
                            _typedAnswer(typedAnswer),
                          ],
                          if (explanation != null && explanation.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text('Proč', style: _label),
                            const SizedBox(height: 3),
                            Text(explanation, style: AppTheme.font(fontSize: 15, color: AppTheme.onSurface, height: 1.5)),
                          ],
                          if (hasSource) ...[
                            const SizedBox(height: 14),
                            _highlightedSentence(),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onFlip,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Otočit zpět na zadání'),
                      ),
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

  /// Napsaná odpověď a slovně, jak moc se shoduje se správným řešením.
  Widget _typedAnswer(TypedAnswer answer) {
    final percent = (answer.score * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tvoje odpověď', style: _label),
        const SizedBox(height: 3),
        Text(
          '${answerScoreLabel(percent)} · shoda $percent %',
          style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w600, color: answerScoreColor(percent)),
        ),
        const SizedBox(height: 2),
        Text(answer.text, style: AppTheme.font(fontSize: 16, color: AppTheme.textSecondary, height: 1.4)),
      ],
    );
  }

  /// Původní věta s podtrženými slovy z kartičky, ať je student ve větě hned najde.
  Widget _highlightedSentence() {
    final sentence = card.sourceSentence!.trim();
    final baseStyle = AppTheme.font(fontSize: 13, color: AppTheme.textTertiary, height: 1.45);
    final markStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.textSecondary,
    );

    final spans = <TextSpan>[const TextSpan(text: 'Z hovoru: „')];
    var position = 0;
    for (final range in highlightRanges(sentence, card.backText)) {
      if (range.start > position) spans.add(TextSpan(text: sentence.substring(position, range.start)));
      spans.add(TextSpan(text: sentence.substring(range.start, range.end), style: markStyle));
      position = range.end;
    }
    spans.add(TextSpan(text: '${sentence.substring(position)}“'));
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
