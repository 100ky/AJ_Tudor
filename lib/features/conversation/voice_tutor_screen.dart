import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/models/chat_message.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/agents/voice_director_agent.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/audio/audio_session_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/smart_chat_bubble.dart';
import 'widgets/voice_tutor/free_talk_tab.dart';
import 'widgets/voice_tutor/history_topic_tab.dart';
import 'widgets/voice_tutor/live_transcript.dart';
import 'widgets/voice_tutor/scenarios_tab.dart';
import 'widgets/voice_tutor/session_setup_view.dart';
import 'widgets/voice_tutor/tutor_banners.dart';
import 'widgets/voice_tutor/tutor_controls.dart';
import 'widgets/voice_tutor/tutor_header.dart';

/// Hlasový tutor: výběr tématu, živý hovor s přepisem a ovládání.
class VoiceTutorScreen extends ConsumerStatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  ConsumerState<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends ConsumerState<VoiceTutorScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

  /// Zvolená záložka v prázdném stavu (bez vybraného scénáře / volného režimu).
  TopicMode _selectedMode = TopicMode.history;

  /// Indikátor generování nových scénářů
  bool _isGeneratingScenarios = false;

  /// Kontrolér pro zadání vlastního příběhu / scénáře na přání
  final _customScenarioController = TextEditingController();
  bool _isCreatingCustomScenario = false;

  /// Animace pro blikající kurzor v live transkriptu
  late AnimationController _cursorController;

  VoiceTutorAgent get _tutor => ref.read(voiceTutorAgentProvider.notifier);

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
        _tutor.selectScenario(scenario.id, scenario.tutorInstruction);
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

  Future<void> _generateScenarios() async {
    setState(() => _isGeneratingScenarios = true);
    try {
      await ref.read(scenarioPlannerAgentProvider).planScenarios();
    } finally {
      if (mounted) {
        setState(() => _isGeneratingScenarios = false);
      }
    }
  }

  /// Zruší vybraný scénář / volný režim a vrátí se k tématu z historie.
  void _clearScenario() {
    _tutor.selectScenario(0, '');
    setState(() => _selectedMode = TopicMode.history);
  }

  void _onModeChanged(TopicMode mode, VoiceTutorState tutorState) {
    setState(() => _selectedMode = mode);
    switch (mode) {
      case TopicMode.history:
        _tutor.selectScenario(0, '');
      case TopicMode.scenarios:
        if (tutorState.scenarioContext == '__free_talk__') {
          _tutor.selectScenario(0, '');
        }
      case TopicMode.freeTalk:
        _tutor.selectScenario(-1, '__free_talk__');
    }
  }

  /// Aktivní režim: vybraný scénář nebo volný hovor mají přednost před zvolenou záložkou.
  TopicMode _activeMode(VoiceTutorState state) {
    if (state.scenarioContext == '__free_talk__') return TopicMode.freeTalk;
    if (state.selectedScenarioId != null && state.selectedScenarioId! > 0) {
      return TopicMode.scenarios;
    }
    return _selectedMode;
  }

  void _interruptTutor() {
    _tutor.interruptPlayback();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tutor ztišen – pokračuj v mluvení 🎤'),
        duration: Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final directorState = ref.watch(voiceDirectorAgentProvider);
    final audioController = ref.watch(audioSessionControllerProvider);
    final waveColor = AppTheme.orbColorForState(tutorState.status.orbKey);

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

    final messages = tutorState.messages;
    final hasMessages =
        messages.isNotEmpty || tutorState.currentTranscript.isNotEmpty;
    final tip = directorState.currentTip;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Adaptivní hlavička (plynulý přechod z velkého banneru do úzké lišty) ─
            TutorHeader(
              tutorState: tutorState,
              waveColor: waveColor,
              activeVolumeStream: activeVolumeStream,
              isIdle: isIdle,
              onClearScenario: _clearScenario,
              onInterruptTutor: _interruptTutor,
            ),

            // ── Chybová zpráva ────────────────────────────────────────────────
            if (tutorState.errorMessage.isNotEmpty)
              TutorErrorBanner(tutorState.errorMessage),

            // ── Hlavní konverzační prostor (bubliny + live přepis) ────────────
            Expanded(
              child: !hasMessages && isIdle
                  ? _buildSessionSetup(tutorState)
                  : _buildConversation(tutorState, isActive),
            ),

            // ── Asistivní vizuální nápověda pro studenta (Voice Director) ─────────
            if (isActive && tip != null && tip.isNotEmpty)
              DirectorTipBanner(
                tip: tip,
                onDismiss: () =>
                    ref.read(voiceDirectorAgentProvider.notifier).dismissTip(),
              ),

            // ── Spodní ovládací panel ──────────────────────────────────────────
            TutorControls(
              status: tutorState.status,
              isIdle: isIdle,
              isActive: isActive,
              onTogglePause: () {
                if (tutorState.status == TutorState.paused) {
                  _tutor.resumeSession();
                } else {
                  _tutor.pauseSession();
                }
              },
              onMainPressed: () {
                if (isIdle) {
                  _tutor.startSession();
                } else {
                  _tutor.stopSession();
                }
              },
              onChangeTopic: () {
                _tutor.forceTopicChange();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Měním téma konverzace...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Prázdný stav před zahájením konverzace (Výběr tématu a scénářů) ───────
  Widget _buildSessionSetup(VoiceTutorState tutorState) {
    final activeMode = _activeMode(tutorState);

    final Widget tabContent;
    switch (activeMode) {
      case TopicMode.history:
        tabContent = const HistoryTopicTab();
      case TopicMode.scenarios:
        tabContent = ScenariosTab(
          key: const ValueKey('scenarios_view'),
          scenarios: ref.watch(availableScenariosProvider).value ?? const <Scenario>[],
          selectedScenarioId: tutorState.selectedScenarioId,
          isGeneratingScenarios: _isGeneratingScenarios,
          onGenerateScenarios: _generateScenarios,
          onToggleScenario: (scenario, wasSelected) {
            if (wasSelected) {
              _tutor.selectScenario(0, '');
            } else {
              _tutor.selectScenario(scenario.id, scenario.tutorInstruction);
            }
          },
          customScenarioController: _customScenarioController,
          isCreatingCustomScenario: _isCreatingCustomScenario,
          onCreateCustomScenario: _createCustomScenario,
        );
      case TopicMode.freeTalk:
        tabContent = FreeTalkTab(
          key: const ValueKey('free_talk_card'),
          onCancel: _clearScenario,
        );
    }

    return SessionSetupView(
      activeMode: activeMode,
      onModeChanged: (mode) => _onModeChanged(mode, tutorState),
      tabContent: tabContent,
    );
  }

  Widget _buildConversation(VoiceTutorState tutorState, bool isActive) {
    final messages = tutorState.messages;
    final itemCount =
        messages.length + (tutorState.currentTranscript.isNotEmpty ? 1 : 0);

    return ShaderMask(
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
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Live transkript na konci listu
          if (index == messages.length) {
            return LiveTranscript(
              transcript: tutorState.currentTranscript,
              cursor: _cursorController,
            );
          }

          final msg = messages[index];

          // Dynamická opacity pro vizuální hloubku
          final distanceFromEnd = messages.length - index;
          final double opacity =
              (1.0 - (distanceFromEnd * 0.08)).clamp(0.15, 1.0);

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: opacity,
            child: _buildMessageBubble(msg),
          );
        },
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
