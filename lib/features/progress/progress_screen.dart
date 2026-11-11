import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/flashcard_stats.dart';
import '../../data/models/progress_trends.dart';
import '../../data/models/skill_profile.dart';
import '../../core/widgets/grouped_section.dart';
import '../../core/widgets/pill_tabs.dart';
import '../skeleton/navigation_provider.dart';
import 'widgets/error_distribution_card.dart';
import 'widgets/fluency_chart_card.dart';
import 'widgets/improvement_section.dart';
import 'widgets/lesson_history_tab.dart';
import 'widgets/mastery_overview_card.dart';
import 'widgets/memory_card.dart';
import 'widgets/recent_errors_card.dart';
import 'widgets/summary_grid.dart';
import 'widgets/vocabulary_card.dart';
import 'widgets/work_on_section.dart';

/// Pokrok: přehled (co se zlepšuje, na čem pracovat, podrobnosti) a historie lekcí.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedTabIndex = 0;

  /// Rozbalené řádky podrobností (stav přežije přepnutí záložek).
  final Set<String> _expanded = {};

  bool _isOpen(String key) => _expanded.contains(key);
  void _toggle(String key) => setState(() => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key));

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final errors = ref.watch(allErrorLogsProvider).value ?? const [];
    final sessions = ref.watch(allSessionsProvider).value ?? const [];
    final stats = ref.watch(flashcardStatsProvider).value ?? const FlashcardStats.empty();
    final trends = ProgressTrends.from(sessions, errors);
    final skills = SkillProfile.from(sessions, errors);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('Pokrok'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: PillTabs(
                labels: const ['Přehled', 'Historie lekcí'],
                selected: _selectedTabIndex,
                onChanged: (index) => setState(() => _selectedTabIndex = index),
              ),
            ),
            Expanded(
              child: _selectedTabIndex == 0
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        SummaryGrid(profile: profile, sessions: sessions),
                        const SizedBox(height: 32),
                        if (!skills.isEmpty) ...[
                          ImprovementSection(skills: skills),
                          const SizedBox(height: 32),
                        ],
                        if (trends.categories.isNotEmpty) ...[
                          WorkOnSection(trends: trends),
                          const SizedBox(height: 32),
                        ],
                        ..._details(profile, errors, sessions, stats),
                      ],
                    )
                  : LessonHistoryTab(sessions: sessions),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(
    UserProfile? profile,
    List<ErrorLog> errors,
    List<Session> sessions,
    FlashcardStats stats,
  ) {
    final cards = <Widget>[
      MasteryOverviewCard(
        stats: stats,
        expanded: _isOpen('cards'),
        onToggle: () => _toggle('cards'),
        onOpenFlashcards: () => ref.read(mainNavigationIndexProvider.notifier).setIndex(2),
      ),
      if (sessions.isNotEmpty)
        FluencyChartCard(
          sessions: sessions,
          expanded: _isOpen('fluency'),
          onToggle: () => _toggle('fluency'),
        ),
      if (errors.isNotEmpty)
        ErrorDistributionCard(
          errors: errors,
          expanded: _isOpen('distribution'),
          onToggle: () => _toggle('distribution'),
        ),
      if (profile?.memoryBriefing != null && profile!.memoryBriefing!.isNotEmpty)
        MemoryCard(
          briefing: profile.memoryBriefing!,
          expanded: _isOpen('memory'),
          onToggle: () => _toggle('memory'),
        ),
      VocabularyCard(
        vocabulary: profile?.vocabularyList ?? const [],
        expanded: _isOpen('vocabulary'),
        onToggle: () => _toggle('vocabulary'),
      ),
      RecentErrorsCard(
        errors: errors,
        expanded: _isOpen('recent'),
        onToggle: () => _toggle('recent'),
        onShowHistory: () => setState(() => _selectedTabIndex = 1),
      ),
    ];
    return [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        cards[i],
      ],
    ];
  }
}
