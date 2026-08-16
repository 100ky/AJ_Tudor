import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../conversation/conversation_screen.dart';
import '../conversation/voice_tutor_screen.dart';
import '../agents/agents_screen.dart';
import '../progress/progress_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/config_provider.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../core/app_theme.dart';

/// Notifier pro správu indexu vybrané záložky v dolní navigaci.
class _SelectedIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Globální provider pro index vybrané stránky.
final _selectedIndexProvider =
    NotifierProvider<_SelectedIndexNotifier, int>(_SelectedIndexNotifier.new);

/// Hlavní kostra aplikace s dolní navigační lištou.
///
/// Zajišťuje přepínání mezi hlavními sekcemi (Chat, Voice, Agenti, Statistiky, Nastavení).
class SkeletonScreen extends ConsumerWidget {
  const SkeletonScreen({super.key});

  /// Seznam stránek dostupných v navigaci.
  static const List<Widget> _pages = [
    ConversationScreen(),
    VoiceTutorScreen(),
    AgentsScreen(),
    ProgressScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(_selectedIndexProvider);
    final apiKey = ref.watch(apiKeyProvider);
    final isLoaded = ref.watch(isApiKeyLoadedProvider);
    final tutorState = ref.watch(voiceTutorAgentProvider);

    final isMissingKey = isLoaded && (apiKey == null || apiKey.isEmpty);
    final isVoiceActive = currentIndex == 1 &&
        (tutorState.status != TutorState.idle &&
            tutorState.status != TutorState.error);

    return Scaffold(
      backgroundColor: AppTheme.background,

      // Warning banner – chybí API klíč
      appBar: isMissingKey && currentIndex != 5
          ? AppBar(
              backgroundColor: AppTheme.warning.withValues(alpha: 0.12),
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 44,
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Chybí Gemini API klíč',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(_selectedIndexProvider.notifier).setIndex(5),
                  child: Text(
                    'NASTAVIT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            )
          : null,

      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        height: isVoiceActive ? 0.0 : 80.0,
        child: ClipRect(
          child: OverflowBox(
            minHeight: 80,
            maxHeight: 80,
            alignment: Alignment.topCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              offset: isVoiceActive ? const Offset(0, 1) : Offset.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.outline, width: 1),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) {
                    ref.read(_selectedIndexProvider.notifier).setIndex(index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: 'Chat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.mic_none_rounded),
                      selectedIcon: Icon(Icons.mic_rounded),
                      label: 'Voice',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.smart_toy_outlined),
                      selectedIcon: Icon(Icons.smart_toy_rounded),
                      label: 'Agenti',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.show_chart_rounded),
                      label: 'Pokrok',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      label: 'Historie',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Nastavení',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
