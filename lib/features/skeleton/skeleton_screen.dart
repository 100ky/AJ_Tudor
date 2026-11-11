import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../conversation/voice_tutor_screen.dart';
import '../conversation/conversation_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/config/config_providers.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/agents/topic_preparation_agent.dart';
import '../../core/app_theme.dart';
import 'navigation_provider.dart';
import 'widgets/app_navigation_bar.dart';

/// Hlavní kostra aplikace: stránky a spodní navigace.
///
/// Indexy stránek:
/// 0: Hovor (hlasový tutor)
/// 1: Dril (gramatický dril a cvičebna)
/// 2: Kartičky
/// 3: Pokrok (statistiky a historie)
/// 4: Profil a nastavení
class SkeletonScreen extends ConsumerStatefulWidget {
  const SkeletonScreen({super.key});

  @override
  ConsumerState<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends ConsumerState<SkeletonScreen> {
  static const List<Widget> _pages = [
    VoiceTutorScreen(),
    ConversationScreen(),
    FlashcardsScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Probrání agenta pro přípravu konverzačního tématu z historie při startu aplikace.
    // API klíč se načítá ze šifrovaného úložiště asynchronně, proto čekáme,
    // až bude k dispozici (spustí se i po prvním zadání klíče v Settings).
    ref.listenManual<String?>(apiKeyProvider, (previous, next) {
      final hadKey = previous != null && previous.isNotEmpty;
      final hasKey = next != null && next.isNotEmpty;
      if (hasKey && !hadKey) {
        ref.read(topicPreparationAgentProvider.notifier).prepareTopic();
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavigationIndexProvider);
    final apiKey = ref.watch(apiKeyProvider);
    final isLoaded = ref.watch(isApiKeyLoadedProvider);
    final tutorState = ref.watch(voiceTutorAgentProvider);

    final isMissingKey = isLoaded && (apiKey == null || apiKey.isEmpty);
    // Během hovoru se navigace schová, aby nic nerušilo
    final isVoiceActive = currentIndex == 0 &&
        (tutorState.status != TutorState.idle && tutorState.status != TutorState.error);
    final navHeight = AppNavigationBar.overhang + AppNavigationBar.barHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          if (isMissingKey && currentIndex != 4)
            _MissingKeyBanner(
              onOpenSettings: () => ref.read(mainNavigationIndexProvider.notifier).setIndex(4),
            ),
          Expanded(
            child: IndexedStack(index: currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        height: isVoiceActive ? 0.0 : navHeight,
        child: ClipRect(
          clipBehavior: isVoiceActive ? Clip.hardEdge : Clip.none,
          child: OverflowBox(
            minHeight: navHeight,
            maxHeight: navHeight,
            alignment: Alignment.topCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              offset: isVoiceActive ? const Offset(0, 1) : Offset.zero,
              child: AppNavigationBar(
                currentIndex: currentIndex,
                onSelect: (index) => ref.read(mainNavigationIndexProvider.notifier).setIndex(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Upozornění nahoře, když chybí Gemini API klíč.
class _MissingKeyBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _MissingKeyBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chybí Gemini API klíč',
                style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onOpenSettings();
              },
              child: const Text('Nastavit'),
            ),
          ],
        ),
      ),
    );
  }
}
