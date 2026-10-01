import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/flashcard_stats.dart';
import '../../core/app_theme.dart';
import '../skeleton/navigation_provider.dart';
import 'widgets/error_distribution_card.dart';
import 'widgets/fluency_chart_card.dart';
import 'widgets/lesson_history_tab.dart';
import 'widgets/mastery_overview_card.dart';
import 'widgets/memory_card.dart';
import 'widgets/recent_errors_card.dart';
import 'widgets/summary_grid.dart';
import 'widgets/vocabulary_card.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedTabIndex = 0;
  bool _isMasteryExpanded = true;
  bool _isFluencyExpanded = true;
  bool _isErrorsExpanded = false;
  bool _isMemoryExpanded = false;
  bool _isVocabExpanded = false;
  bool _isRecentErrorsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final errors = ref.watch(allErrorLogsProvider).value ?? const [];
    final sessions = ref.watch(allSessionsProvider).value ?? const [];
    final stats =
        ref.watch(flashcardStatsProvider).value ?? const FlashcardStats.empty();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Tvůj pokrok',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // ── Přepínač: Přehled a vývoj vs Historie lekcí ────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.analytics_outlined, size: 16),
                  label: Text('Přehled a vývoj'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.history_rounded, size: 16),
                  label: Text('Historie lekcí'),
                ),
              ],
              selected: {_selectedTabIndex.clamp(0, 1)},
              onSelectionChanged: (set) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedTabIndex = set.first;
                });
              },
            ),
          ),

          // ── Obsah podle vybrané záložky ────────────────────────
          Expanded(
            child: _selectedTabIndex == 0
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SummaryGrid(profile: profile, sessions: sessions),
                        const SizedBox(height: 14),
                        MasteryOverviewCard(
                          stats: stats,
                          expanded: _isMasteryExpanded,
                          onToggle: () => setState(
                              () => _isMasteryExpanded = !_isMasteryExpanded),
                          onOpenFlashcards: () => ref
                              .read(mainNavigationIndexProvider.notifier)
                              .setIndex(2),
                        ),
                        const SizedBox(height: 12),
                        if (sessions.isNotEmpty) ...[
                          FluencyChartCard(
                            sessions: sessions,
                            expanded: _isFluencyExpanded,
                            onToggle: () => setState(
                                () => _isFluencyExpanded = !_isFluencyExpanded),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (errors.isNotEmpty) ...[
                          ErrorDistributionCard(
                            errors: errors,
                            expanded: _isErrorsExpanded,
                            onToggle: () => setState(
                                () => _isErrorsExpanded = !_isErrorsExpanded),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (profile?.memoryBriefing != null &&
                            profile!.memoryBriefing!.isNotEmpty) ...[
                          MemoryCard(
                            briefing: profile.memoryBriefing!,
                            expanded: _isMemoryExpanded,
                            onToggle: () => setState(
                                () => _isMemoryExpanded = !_isMemoryExpanded),
                          ),
                          const SizedBox(height: 12),
                        ],
                        VocabularyCard(
                          vocabulary: profile?.vocabularyList ?? const [],
                          expanded: _isVocabExpanded,
                          onToggle: () => setState(
                              () => _isVocabExpanded = !_isVocabExpanded),
                        ),
                        const SizedBox(height: 12),
                        RecentErrorsCard(
                          errors: errors,
                          expanded: _isRecentErrorsExpanded,
                          onToggle: () => setState(() =>
                              _isRecentErrorsExpanded = !_isRecentErrorsExpanded),
                          onShowHistory: () =>
                              setState(() => _selectedTabIndex = 1),
                        ),
                      ],
                    ),
                  )
                : LessonHistoryTab(sessions: sessions),
          ),
        ],
      ),
    );
  }
}
