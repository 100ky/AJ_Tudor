import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/progress_trends.dart';
import '../../../../services/agents/voice_tutor_agent.dart';
import '../../../../services/flashcards/due_conversation_cards.dart';
import '../../../../services/prompt/system_prompt_builder.dart';

/// Podrobnosti „Lekce s kartičkami“: hovor projde dnešní kartičky jednu po druhé.
class LessonTab extends ConsumerWidget {
  const LessonTab({super.key});

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
    final muted = AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.45);

    return switch (cards) {
      AsyncData(:final value) when value.isEmpty => Text(
          'Na dnešek nemáš kartičky, které by šly procvičit v hovoru. Zkus pokec, kartičky z něj přibudou.',
          style: muted,
        ),
      AsyncData(:final value) => _LessonPlan(czech: [for (final card in value) card.czech], goal: goal?.label),
      AsyncError() => Text('Kartičky se nepodařilo načíst.', style: muted.copyWith(color: AppTheme.error)),
      _ => const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
    };
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
          style: AppTheme.font(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Tutor ti u každého výrazu připraví situaci a ty ho použiješ ve větě. Když si nevzpomeneš, '
          'napoví ti česky. Nejvýš ${VoiceTutorAgent.lessonMinutes} minut, pak můžete pokračovat pokecem.',
          style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.45),
        ),
        if (goal != null) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Gramatický cíl: '),
              TextSpan(text: goal, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const TextSpan(text: ', v posledních lekcích nejčastější chyba'),
            ]),
            style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final text in czech)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(10)),
                child: Text(text, style: AppTheme.font(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              ),
          ],
        ),
      ],
    );
  }
}
