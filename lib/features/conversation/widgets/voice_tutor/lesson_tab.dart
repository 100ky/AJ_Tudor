import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/progress_trends.dart';
import '../../../../services/agents/voice_tutor_agent.dart';
import '../../../../services/flashcards/due_conversation_cards.dart';
import '../../../../services/prompt/system_prompt_builder.dart';

/// Záložka „Lekce“: hovor projde dnešní kartičky jednu po druhé.
class LessonTab extends ConsumerWidget {
  /// Zruší lekci a vrátí se k tématu z historie.
  final VoidCallback onCancel;

  const LessonTab({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueFlashcardsProvider);
    final goal = ProgressTrends.recentGrammarGoal(
      ref.watch(allSessionsProvider).value ?? const [],
      ref.watch(allErrorLogsProvider).value ?? const [],
    );
    final cards = due.whenData(
      (list) => conversationCardsFromDue(list).cards.take(VoiceTutorAgent.lessonCardCount).toList(),
    );

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      color: AppTheme.accent.withValues(alpha: 0.06),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'LEKCE S KARTIČKAMI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          switch (cards) {
            AsyncData(:final value) when value.isEmpty => Text(
                'Na dnešek nemáš kartičky, které by šly procvičit v hovoru. Zkus pokec, kartičky z něj přibudou.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.surfaceTextColor(context),
                  height: 1.35,
                ),
              ),
            AsyncData(:final value) => _LessonPlan(czech: [for (final card in value) card.czech], goal: goal?.label),
            AsyncError() => Text(
                'Kartičky se nepodařilo načíst.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.error),
              ),
            _ => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
          },
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aktivní pro příští hovor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCancel();
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Zrušit a zpět', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Co lekce projde: počet výrazů, postup a české strany kartiček.
class _LessonPlan extends StatelessWidget {
  final List<String> czech;

  /// Gramatický cíl lekce (nejčastější chyba v posledních lekcích), když je.
  final String? goal;

  const _LessonPlan({required this.czech, this.goal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projdeme ${SystemPromptBuilder.expressionCount(czech.length)} z tvých kartiček',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tutor ti u každého výrazu připraví situaci a ty ho použiješ ve větě. Když si nevzpomeneš, '
          'napoví ti česky. Nejvýš ${VoiceTutorAgent.lessonMinutes} minut, pak můžete pokračovat pokecem.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppTheme.surfaceTextColor(context),
            height: 1.35,
          ),
        ),
        if (goal != null) ...[
          const SizedBox(height: 8),
          Text(
            'Gramatický cíl: $goal (v posledních lekcích nejčastější chyba)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final text in czech)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
