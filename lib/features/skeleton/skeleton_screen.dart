import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../conversation/conversation_screen.dart';
import '../conversation/voice_tutor_screen.dart';
import '../agents/agents_screen.dart';
import '../progress/progress_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

/// Notifier pro správu indexu vybrané záložky v dolní navigaci.
class _SelectedIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Globální provider pro index vybrané stránky.
final _selectedIndexProvider = NotifierProvider<_SelectedIndexNotifier, int>(_SelectedIndexNotifier.new);

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

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // Změna aktivní záložky
          ref.read(_selectedIndexProvider.notifier).setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Agenti',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Pokrok',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historie',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Nastavení',
          ),
        ],
      ),
    );
  }
}
