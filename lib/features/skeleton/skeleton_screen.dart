import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../conversation/conversation_screen.dart';
import '../conversation/voice_tutor_screen.dart';
import '../agents/agents_screen.dart';
import '../progress/progress_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/config_provider.dart';

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
    final apiKey = ref.watch(apiKeyProvider);
    final isLoaded = ref.watch(isApiKeyLoadedProvider);

    // Pokud je načítání hotovo a klíč chybí, zobrazíme upozornění
    final isMissingKey = isLoaded && (apiKey == null || apiKey.isEmpty);

    return Scaffold(
      appBar: isMissingKey && currentIndex != 5 // Nezobrazovat, pokud jsme už v nastavení
          ? AppBar(
              backgroundColor: Colors.orange.shade100,
              toolbarHeight: 48,
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Chybí Gemini API klíč',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => ref.read(_selectedIndexProvider.notifier).setIndex(5),
                  child: const Text('NASTAVIT'),
                ),
              ],
            )
          : null,
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
