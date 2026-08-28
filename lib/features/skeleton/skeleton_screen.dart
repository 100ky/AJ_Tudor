import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../conversation/conversation_screen.dart';
import '../conversation/voice_tutor_screen.dart';
import '../progress/progress_screen.dart';
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

/// Hlavní kostra aplikace s čistou 4-položkovou navigací a živým gradient pozadím.
///
/// Zajišťuje přepínání mezi hlavními sekcemi:
/// 0: Voice (Hlasový tutor)
/// 1: Chat (Textový chat a dril)
/// 2: Pokrok (Statistiky a historie)
/// 3: Profil & Nastavení
class SkeletonScreen extends ConsumerStatefulWidget {
  const SkeletonScreen({super.key});

  @override
  ConsumerState<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends ConsumerState<SkeletonScreen>
    with SingleTickerProviderStateMixin {
  /// Kontrolér pro pomalou ambientní animaci plovoucích blobů
  late AnimationController _ambientBlobController;

  static const List<Widget> _pages = [
    VoiceTutorScreen(),
    ConversationScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _ambientBlobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientBlobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(_selectedIndexProvider);
    final apiKey = ref.watch(apiKeyProvider);
    final isLoaded = ref.watch(isApiKeyLoadedProvider);
    final tutorState = ref.watch(voiceTutorAgentProvider);

    final isMissingKey = isLoaded && (apiKey == null || apiKey.isEmpty);
    final isVoiceActive = currentIndex == 0 &&
        (tutorState.status != TutorState.idle &&
            tutorState.status != TutorState.error);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Živé ambientní gradient bloby ──────────────────────────────────
          AnimatedBuilder(
            animation: _ambientBlobController,
            builder: (context, _) {
              final t = _ambientBlobController.value;
              final sinT = math.sin(t * math.pi);
              final cosT = math.cos(t * math.pi);

              return Stack(
                children: [
                  // Indigo blob (horní roh)
                  Positioned(
                    top: -120 + (sinT * 20),
                    right: -80 + (cosT * 15),
                    child: Container(
                      width: 320 + (sinT * 20),
                      height: 320 + (sinT * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.blobPrimary.withValues(
                              alpha: 0.18 + (sinT * 0.06),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pink/Violet blob (spodní roh)
                  Positioned(
                    bottom: -60 + (cosT * 25),
                    left: -100 + (sinT * 15),
                    child: Container(
                      width: 290 + (cosT * 20),
                      height: 290 + (cosT * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.blobSecondary.withValues(
                              alpha: 0.16 + (cosT * 0.05),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cyan blob (střední zóna)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35 +
                        (sinT * 30),
                    left: MediaQuery.of(context).size.width * 0.25 +
                        (cosT * 20),
                    child: Container(
                      width: 220 + (sinT * 15),
                      height: 220 + (sinT * 15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.blobTertiary.withValues(
                              alpha: 0.14 + (sinT * 0.04),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Hlavní obsah ───────────────────────────────────────────────────
          Column(
            children: [
              // Warning banner – chybí API klíč
              if (isMissingKey && currentIndex != 3)
                SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chybí Gemini API klíč',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(_selectedIndexProvider.notifier)
                                      .setIndex(3);
                                },
                                child: Text(
                                  'NASTAVIT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Stránky
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Glass NavigationBar (4 vzdušné záložky) ──────────────────────────
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
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.glassDark : AppTheme.glass,
                      border: Border(
                        top: BorderSide(
                          color: (isDark ? AppTheme.outlineDark : AppTheme.outline)
                              .withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(_selectedIndexProvider.notifier)
                            .setIndex(index);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.mic_none_rounded),
                          selectedIcon: Icon(Icons.mic_rounded),
                          label: 'Hlas',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.chat_bubble_outline_rounded),
                          selectedIcon: Icon(Icons.chat_bubble_rounded),
                          label: 'Chat',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.insights_rounded),
                          selectedIcon: Icon(Icons.show_chart_rounded),
                          label: 'Pokrok',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Profil',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
