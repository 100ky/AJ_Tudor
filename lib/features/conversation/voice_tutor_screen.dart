import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/audio/audio_session_controller.dart';
import '../../data/models/chat_message.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/smart_chat_bubble.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/agents/topic_preparation_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../data/database/app_database.dart';
import 'widgets/fluid_voice_wave.dart';




class VoiceTutorScreen extends ConsumerStatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  ConsumerState<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends ConsumerState<VoiceTutorScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  /// Zvolená záložka v prázdném stavu: 0 = Téma z historie, 1 = Scénáře, 2 = Volný pokec
  int _selectedModeTab = 0;

  /// Indikátor generování nových scénářů
  bool _isGeneratingScenarios = false;

  /// Kontrolér pro zadání vlastního příběhu / scénáře na přání
  final _customScenarioController = TextEditingController();
  bool _isCreatingCustomScenario = false;

  /// Animace pro blikající kurzor v live transkriptu
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cursorController.dispose();
    _customScenarioController.dispose();
    super.dispose();
  }

  Future<void> _createCustomScenario() async {
    final text = _customScenarioController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isCreatingCustomScenario = true);
    HapticFeedback.mediumImpact();

    try {
      final scenario = await ref
          .read(scenarioPlannerAgentProvider)
          .planCustomScenario(text);

      if (!mounted) return;

      if (scenario != null) {
        _customScenarioController.clear();
        ref
            .read(voiceTutorAgentProvider.notifier)
            .selectScenario(scenario.id, scenario.tutorInstruction);
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scénář "${scenario.title}" byl vytvořen a aktivován! 🎭',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Nepodařilo se vygenerovat scénář. Zkontrolujte připojení.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při tvorbě scénáře: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingCustomScenario = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Převede [TutorState] na string klíč pro [AppTheme.orbColorForState]
  String _stateToLabel(TutorState status) {
    switch (status) {
      case TutorState.listening:
        return 'listening';
      case TutorState.thinking:
        return 'thinking';
      case TutorState.speaking:
        return 'speaking';
      case TutorState.connecting:
        return 'connecting';
      case TutorState.reconnecting:
        return 'reconnecting';
      case TutorState.paused:
        return 'paused';
      case TutorState.error:
        return 'error';
      case TutorState.idle:
        return 'idle';
    }
  }

  String _getStatusText(TutorState status) {
    switch (status) {
      case TutorState.connecting:
        return 'Připojování...';
      case TutorState.reconnecting:
        return 'Obnovování spojení...';
      case TutorState.listening:
        return 'Tutor poslouchá';
      case TutorState.thinking:
        return 'Tutor přemýšlí';
      case TutorState.speaking:
        return 'Tutor mluví';
      case TutorState.paused:
        return 'Pozastaveno';
      case TutorState.error:
        return 'Chyba spojení';
      case TutorState.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final audioController = ref.watch(audioSessionControllerProvider);
    final stateLabel = _stateToLabel(tutorState.status);
    final waveColor = AppTheme.orbColorForState(stateLabel);

    final isIdle = tutorState.status == TutorState.idle ||
        tutorState.status == TutorState.error;
    final isActive = !isIdle;

    // Automatický scroll při změně zpráv nebo transkriptu
    ref.listen(voiceTutorAgentProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.currentTranscript != next.currentTranscript) {
        _scrollToBottom();
      }
    });

    // Aktivní volume stream dle stavu
    final Stream<double>? activeVolumeStream =
        (tutorState.status == TutorState.listening)
            ? audioController.captureVolumeStream
            : (tutorState.status == TutorState.speaking)
                ? audioController.playbackVolumeStream
                : null;

    final visibleMessages = _getVisibleMessages(tutorState);
    final hasMessages =
        visibleMessages.isNotEmpty || tutorState.currentTranscript.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Adaptivní hlavička (plynulý přechod z velkého banneru do úzké lišty) ─
            _buildAnimatedHeader(
              tutorState: tutorState,
              stateLabel: stateLabel,
              waveColor: waveColor,
              activeVolumeStream: activeVolumeStream,
              isIdle: isIdle,
            ),

            // ── Chybová zpráva ────────────────────────────────────────────────
            if (tutorState.errorMessage.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.error.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.25)),
                  shadows: const [],
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppTheme.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tutorState.errorMessage,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Hlavní konverzační prostor (bubliny + live přepis) ────────────
            Expanded(
              child: !hasMessages && isIdle
                  ? _buildEmptyState(tutorState)
                  : ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.08, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          isActive ? 12 : 24,
                          16,
                          isActive ? 100 : 16,
                        ),
                        itemCount: _getVisibleItemCount(tutorState),
                        itemBuilder: (context, index) {
                          // Live transkript na konci listu
                          if (index == visibleMessages.length) {
                            return _buildLiveTranscript(
                                tutorState.currentTranscript);
                          }

                          final msg = visibleMessages[index];

                          // Dynamická opacity pro vizuální hloubku
                          final distanceFromEnd =
                              visibleMessages.length - index;
                          final double opacity =
                              (1.0 - (distanceFromEnd * 0.08))
                                  .clamp(0.15, 1.0);

                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: opacity,
                            child: _buildMessageBubble(msg),
                          );
                        },
                      ),
                    ),
            ),

            // ── Spodní ovládací panel ──────────────────────────────────────────
            _buildControls(tutorState, isIdle, isActive),
          ],
        ),
      ),
    );
  }

  // ── Adaptivní hlavička (plynulý přechod z velkého banneru do úzké lišty) ───
  Widget _buildAnimatedHeader({
    required VoiceTutorState tutorState,
    required String stateLabel,
    required Color waveColor,
    required Stream<double>? activeVolumeStream,
    required bool isIdle,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
              child: isIdle
                  ? _buildHeroHeader(
                      key: const ValueKey('hero_header'),
                      tutorState: tutorState,
                      stateLabel: stateLabel,
                      waveColor: waveColor,
                      activeVolumeStream: activeVolumeStream,
                    )
                  : _buildCompactHeader(
                      key: const ValueKey('compact_header'),
                      tutorState: tutorState,
                      stateLabel: stateLabel,
                      waveColor: waveColor,
                      activeVolumeStream: activeVolumeStream,
                    ),
          ),
        ),
      );
  }

  // ── Hero Header (Klidový stav / Idle – velký wave banner) ───────────────────
  Widget _buildHeroHeader({
    Key? key,
    required VoiceTutorState tutorState,
    required String stateLabel,
    required Color waveColor,
    required Stream<double>? activeVolumeStream,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titulek Hlasový Tutor
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tutorState.status == TutorState.idle ||
                          tutorState.status == TutorState.error
                      ? AppTheme.onSurfaceMuted
                      : AppTheme.success,
                  boxShadow: tutorState.status != TutorState.idle &&
                          tutorState.status != TutorState.error
                      ? [
                          BoxShadow(
                            color: AppTheme.success.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Hlasový Tutor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Velký Fluid Wave Banner (Siri / Gemini styl)
          Container(
            width: double.infinity,
            height: 105,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppTheme.glassLightColor(context),
              border: Border.all(
                color: waveColor.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: waveColor.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FluidVoiceWave(
                color: waveColor,
                stateLabel: stateLabel,
                volumeStream: activeVolumeStream,
                height: 105,
                isCompact: false,
                showAmbientGlow: true,
              ),
            ),
          ),

          // Stavový text (zobrazen pouze pokud má text, např. chyba)
          if (_getStatusText(tutorState.status).isNotEmpty) ...[
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getStatusText(tutorState.status),
                key: ValueKey(tutorState.status),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],

          // Aktivní scénář / režim chip
          if (tutorState.selectedScenarioId != null) ...[
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                tutorState.scenarioContext == '__free_talk__'
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.theater_comedy_rounded,
                size: 14,
                color: AppTheme.accent,
              ),
              label: Text(
                tutorState.scenarioContext == '__free_talk__'
                    ? 'Volný rozhovor aktivní'
                    : 'Role-Play scénář aktivní',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: AppTheme.accent.withValues(alpha: 0.08),
              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.25)),
              deleteIcon: Icon(Icons.close_rounded,
                  size: 14, color: AppTheme.onSurfaceMuted),
              onDeleted: () {
                HapticFeedback.lightImpact();
                ref
                    .read(voiceTutorAgentProvider.notifier)
                    .selectScenario(0, '');
                setState(() => _selectedModeTab = 0);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Kompaktní Header (Aktivní hovor – čistá vlna přes celý úzký řádek) ─────
  Widget _buildCompactHeader({
    Key? key,
    required VoiceTutorState tutorState,
    required String stateLabel,
    required Color waveColor,
    required Stream<double>? activeVolumeStream,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Světelná zvuková vlna rozprostřená přes CELÝ úzký řádek (klepnutím lze tutora ztišit)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (tutorState.status == TutorState.speaking) {
                  ref.read(voiceTutorAgentProvider.notifier).interruptPlayback();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tutor ztišen – pokračuj v mluvení 🎤'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: FluidVoiceWave(
                color: waveColor,
                stateLabel: stateLabel,
                volumeStream: activeVolumeStream,
                height: 52,
                isCompact: true,
                showAmbientGlow: true,
              ),
            ),
          ),

          // 2. Pouze případný scénář badge vpravo, pokud je aktivní
          if (tutorState.selectedScenarioId != null &&
              tutorState.selectedScenarioId! > 0)
            Positioned(
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor(context)
                      .withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.theater_comedy_rounded,
                      size: 13,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Roleplay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(voiceTutorAgentProvider.notifier)
                            .selectScenario(0, '');
                        setState(() => _selectedModeTab = 0);
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Prázdný stav před zahájením konverzace (Výběr tématu a scénářů) ───────
  Widget _buildEmptyState(VoiceTutorState tutorState) {
    final activeTab = _getActiveModeTab(tutorState);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ── Přepínač režimu tématu ──────────────────────────────────────
            SegmentedButton<int>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.lightbulb_rounded, size: 14),
                  label: Text('Historie', maxLines: 1),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.theater_comedy_rounded, size: 14),
                  label: Text('Scénáře', maxLines: 1),
                ),
                ButtonSegment<int>(
                  value: 2,
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: Text('Volný', maxLines: 1),
                ),
              ],
              selected: {activeTab},
              onSelectionChanged: (set) {
                final mode = set.first;
                HapticFeedback.selectionClick();
                setState(() => _selectedModeTab = mode);
                final notifier = ref.read(voiceTutorAgentProvider.notifier);
                if (mode == 0) {
                  notifier.selectScenario(0, '');
                } else if (mode == 1) {
                  if (tutorState.scenarioContext == '__free_talk__') {
                    notifier.selectScenario(0, '');
                  }
                } else if (mode == 2) {
                  notifier.selectScenario(-1, '__free_talk__');
                }
              },
            ),

            const SizedBox(height: 14),

            // ── Obsah podle vybraného režimu ────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: activeTab == 0
                  ? _buildHistoryTopicTab()
                  : activeTab == 1
                      ? _buildScenariosTab(tutorState)
                      : _buildFreeTalkTab(tutorState),
            ),
          ],
        ),
      ),
    );
  }

  int _getActiveModeTab(VoiceTutorState state) {
    if (state.scenarioContext == '__free_talk__') return 2;
    if (state.selectedScenarioId != null && state.selectedScenarioId! > 0) {
      return 1;
    }
    return _selectedModeTab;
  }

  // ── Záložka 0: Téma z historie ──────────────────────────────────────────────
  Widget _buildHistoryTopicTab() {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final preparedTopic = topicState.topic;

    if (topicState.isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Příprava tématu z historie...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    if (preparedTopic == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Text(
              'Zatím nemáš připravené téma.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref
                    .read(topicPreparationAgentProvider.notifier)
                    .prepareTopic(force: true);
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: const Text('Připravit téma z historie'),
            ),
          ],
        ),
      );
    }

    final isRandom = preparedTopic.isRandomTopic;

    return GlassContainer(
      key: const ValueKey('history_topic_card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      color: isRandom
          ? AppTheme.accent.withValues(alpha: 0.08)
          : AppTheme.primary.withValues(alpha: 0.06),
      border: Border.all(
        color: isRandom
            ? AppTheme.accent.withValues(alpha: 0.35)
            : AppTheme.primary.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRandom ? Icons.casino_rounded : Icons.lightbulb_rounded,
                size: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRandom
                      ? 'DIVOKÁ KARTA (NÁHODNÉ TÉMA)'
                      : 'TÉMA NA POKEC Z HISTORIE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(topicPreparationAgentProvider.notifier)
                      .prepareTopic(force: true);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Jiné téma',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preparedTopic.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '„${preparedTopic.openerEn}“',
            style: GoogleFonts.plusJakartaSans(
              fontStyle: FontStyle.italic,
              fontSize: 12.5,
              color: AppTheme.surfaceTextColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Aktivní téma pro hovor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomScenarioInput() {
    final isDark = AppTheme.isDark(context);

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      color: AppTheme.accent.withValues(alpha: isDark ? 0.08 : 0.04),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'VLASTNÍ PŘÍBĚH / SCÉNÁŘ NA PŘÁNÍ ✍️',
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
          TextField(
            controller: _customScenarioController,
            maxLines: 2,
            minLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textColor(context),
            ),
            decoration: InputDecoration(
              hintText: 'Popiš situaci... (např. Pohovor v IT firmě, nákup veterána v Londýně, hádka se sousedem)',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.mutedTextColor(context),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isCreatingCustomScenario ? null : _createCustomScenario,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
              ),
              icon: _isCreatingCustomScenario
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                _isCreatingCustomScenario ? 'Tvořím scénář...' : 'Vytvořit a aktivovat ✨',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Záložka 1: Scénáře na míru (Role-play) ─────────────────────────────────
  Widget _buildScenariosTab(VoiceTutorState tutorState) {
    final repo = ref.watch(sessionRepositoryProvider);

    return StreamBuilder<List<Scenario>>(
      stream: repo.watchAvailableScenarios(),
      builder: (context, snapshot) {
        final scenarios = snapshot.data ?? [];

        return Column(
          key: const ValueKey('scenarios_view'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Vlastní promptované téma / příběh
            _buildCustomScenarioInput(),
            const SizedBox(height: 14),

            if (scenarios.isEmpty)
              GlassContainer(
                key: const ValueKey('scenarios_empty'),
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    Icon(
                      Icons.theater_comedy_rounded,
                      size: 32,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Žádné předpřipravené scénáře',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vypromptuj si vlastní příběh výše, nebo si nech vygenerovat 3 scénáře na míru.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isGeneratingScenarios
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              setState(() => _isGeneratingScenarios = true);
                              try {
                                await ref
                                    .read(scenarioPlannerAgentProvider)
                                    .planScenarios();
                              } finally {
                                if (mounted) {
                                  setState(() => _isGeneratingScenarios = false);
                                }
                              }
                            },
                      icon: _isGeneratingScenarios
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 15),
                      label: Text(_isGeneratingScenarios
                          ? 'Plánuji scénáře...'
                          : 'Vygenerovat scénáře na míru'),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.theater_comedy_rounded,
                        size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      'ROLE-PLAY SCÉNÁŘE (${scenarios.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.accent,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _isGeneratingScenarios
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              setState(() => _isGeneratingScenarios = true);
                              try {
                                await ref
                                    .read(scenarioPlannerAgentProvider)
                                    .planScenarios();
                              } finally {
                                if (mounted) {
                                  setState(() => _isGeneratingScenarios = false);
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isGeneratingScenarios
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 1.8),
                                  )
                                : Icon(Icons.refresh_rounded,
                                    size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Přeplánovat',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...scenarios.map((s) => _buildVoiceScenarioCard(
                    s,
                    tutorState.selectedScenarioId == s.id,
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildVoiceScenarioCard(Scenario s, bool isSelected) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          final notifier = ref.read(voiceTutorAgentProvider.notifier);
          if (isSelected) {
            notifier.selectScenario(0, '');
          } else {
            notifier.selectScenario(s.id, s.tutorInstruction);
          }
        },
        child: GlassContainer(
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? AppTheme.accent.withValues(alpha: isDark ? 0.22 : 0.08)
              : null,
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.55)
                : (isDark ? AppTheme.outlineDark : AppTheme.outline),
            width: isSelected ? 1.5 : 1.0,
          ),
          shadows: isSelected ? AppTheme.glassShadow : AppTheme.glassShadowLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.theater_comedy_rounded,
                      size: 15,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDifficultyBadge(s.difficulty),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.surfaceTextColor(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.mutedTextColor(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSelected
                        ? 'Vybráno pro příští hovor'
                        : 'Klepnutím vybrat pro hovor',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = AppTheme.success;
        break;
      case 'medium':
        color = AppTheme.warning;
        break;
      case 'hard':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.onSurfaceMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Záložka 2: Volný rozhovor ───────────────────────────────────────────────
  Widget _buildFreeTalkTab(VoiceTutorState tutorState) {
    return GlassContainer(
      key: const ValueKey('free_talk_card'),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      color: AppTheme.accent.withValues(alpha: 0.06),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'SPONTÁNNÍ ROZHOVOR',
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
          Text(
            'Volný pokec o čemkoliv',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Žádný konkrétní scénář ani předem dané téma. Přirozený přátelský rozhovor v angličtině o tom, co tě zrovna napadne.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppTheme.surfaceTextColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14, color: AppTheme.accent),
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
                  ref
                      .read(voiceTutorAgentProvider.notifier)
                      .selectScenario(0, '');
                  setState(() => _selectedModeTab = 0);
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label:
                    const Text('Zrušit a zpět', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Spodní ovládací prvky (Mic / Pause / Stop / Topic) ─────────────────────
  Widget _buildControls(
      VoiceTutorState tutorState, bool isIdle, bool isActive) {
    final isPaused = tutorState.status == TutorState.paused;
    final isLiveSession = tutorState.status == TutorState.listening ||
        tutorState.status == TutorState.speaking ||
        tutorState.status == TutorState.thinking;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        isActive ? 8 : 12,
        24,
        isActive ? 24 : 32,
      ),
      decoration: isActive
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppTheme.backgroundColor(context),
                  AppTheme.backgroundColor(context).withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PAUSE / RESUME (během aktivního hovoru)
          if (isActive)
            _buildSecondaryButton(
              heroTag: 'pause_btn',
              icon: isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: AppTheme.warning,
              tooltip: isPaused ? 'Pokračovat' : 'Pozastavit',
              onPressed: () {
                HapticFeedback.lightImpact();
                final notifier =
                    ref.read(voiceTutorAgentProvider.notifier);
                if (isPaused) {
                  notifier.resumeSession();
                } else {
                  notifier.pauseSession();
                }
              },
            ),

          if (isActive) const SizedBox(width: 24),

          // HLAVNÍ TLAČÍTKO (MIC / STOP)
          _buildMainButton(
            isIdle: isIdle,
            onPressed: () {
              HapticFeedback.mediumImpact();
              final notifier = ref.read(voiceTutorAgentProvider.notifier);
              if (isIdle) {
                notifier.startSession();
              } else {
                notifier.stopSession();
              }
            },
          ),

          // ZMĚNIT TÉMA (jen při aktivní session)
          if (isActive) ...[
            const SizedBox(width: 24),
            _buildSecondaryButton(
              heroTag: 'topic_btn',
              icon: Icons.shuffle_rounded,
              color: (isLiveSession && tutorState.status != TutorState.thinking)
                  ? AppTheme.primary
                  : AppTheme.onSurfaceMuted,
              tooltip: 'Změnit téma',
              onPressed: (isLiveSession && tutorState.status != TutorState.thinking)
                  ? () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(voiceTutorAgentProvider.notifier)
                          .forceTopicChange();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Měním téma konverzace...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : () {},
            ),
          ],
        ],
      ),
    );
  }

  /// Hlavní velké tlačítko (mic / stop) s gradient a glow efektem
  Widget _buildMainButton({
    required bool isIdle,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isIdle ? 76 : 68,
        height: isIdle ? 76 : 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isIdle
                ? [AppTheme.primaryLight, AppTheme.primaryDark]
                : [AppTheme.error, const Color(0xFFDC2626)],
          ),
          boxShadow: [
            BoxShadow(
              color: (isIdle ? AppTheme.primary : AppTheme.error)
                  .withValues(alpha: 0.4),
              blurRadius: isIdle ? 22 : 18,
              spreadRadius: isIdle ? 2 : 1,
            ),
          ],
        ),
        child: Icon(
          isIdle ? Icons.mic_rounded : Icons.stop_rounded,
          size: isIdle ? 36 : 32,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Sekundární tlačítko (pause, topic change) – glass styl
  Widget _buildSecondaryButton({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }

  // ── Pomocné metody pro zprávy a bubliny ─────────────────────────────────────

  List<ChatMessage> _getVisibleMessages(VoiceTutorState state) =>
      state.messages;

  int _getVisibleItemCount(VoiceTutorState state) =>
      state.messages.length + (state.currentTranscript.isNotEmpty ? 1 : 0);

  Widget _buildLiveTranscript(String transcript) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        color: AppTheme.speaking.withValues(alpha: 0.06),
        border: Border.all(
            color: AppTheme.speaking.withValues(alpha: 0.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Blikající kurzor
                AnimatedBuilder(
                  animation: _cursorController,
                  builder: (context, _) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.speaking.withValues(
                          alpha: _cursorController.value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TUTOR SPEAKS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.speaking.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transcript,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textColor(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final useSmartBubbles = ref.watch(smartBubblesEnabledProvider);
    if (useSmartBubbles) {
      return SmartChatBubble(
        message: msg,
      );
    }
    return ChatBubble(
      text: msg.text,
      isUser: msg.isUser,
    );
  }
}
