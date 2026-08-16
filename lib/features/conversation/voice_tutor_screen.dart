import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/audio/audio_session_controller.dart';
import '../../data/models/chat_message.dart';
import '../../core/app_theme.dart';
import 'widgets/liquid_voice_orb.dart';

class VoiceTutorScreen extends ConsumerStatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  ConsumerState<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends ConsumerState<VoiceTutorScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();

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
    super.dispose();
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
        return 'Připraven ke startu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final audioController = ref.watch(audioSessionControllerProvider);
    final stateLabel = _stateToLabel(tutorState.status);
    final orbColor = AppTheme.orbColorForState(stateLabel);

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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ── Orb sekce ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Liquidní orb
                    LiquidVoiceOrb(
                      color: orbColor,
                      stateLabel: stateLabel,
                      volumeStream: activeVolumeStream,
                      size: 160,
                    ),
                    // Ikona stavu (přes orb)
                    OrbStateIcon(stateLabel: stateLabel, color: orbColor),
                  ],
                ),

                const SizedBox(height: 4),

                // Stavový text
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

                // Aktivní scénář chip
                if (tutorState.selectedScenarioId != null) ...[
                  const SizedBox(height: 10),
                  Chip(
                    avatar: Icon(
                      Icons.theater_comedy_rounded,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    label: Text(
                      'Role-Play scénář aktivní',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor:
                        AppTheme.accent.withValues(alpha: 0.1),
                    side: BorderSide(
                        color: AppTheme.accent.withValues(alpha: 0.3)),
                    deleteIcon: Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.onSurfaceMuted),
                    onDeleted: () {
                      ref
                          .read(voiceTutorAgentProvider.notifier)
                          .selectScenario(0, '');
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── Chybová zpráva ────────────────────────────────────────────────
          if (tutorState.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tutorState.errorMessage,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Historie konverzace s efektem mizení (ShaderMask) ─────────────
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white],
                  stops: [0.0, 0.15, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.fromLTRB(16, 32, 16, 8),
                itemCount: _getVisibleItemCount(tutorState),
                itemBuilder: (context, index) {
                  final visibleMessages = _getVisibleMessages(tutorState);

                  // Live transkript na konci listu
                  if (index == visibleMessages.length) {
                    return _buildLiveTranscript(tutorState.currentTranscript);
                  }

                  final msg = visibleMessages[index];

                  // Dynamická opacity dle vzdálenosti od konce
                  final distanceFromEnd = visibleMessages.length - index;
                  final double opacity =
                      (1.0 - (distanceFromEnd * 0.12)).clamp(0.06, 1.0);

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: opacity,
                    child: _buildMessageBubble(msg),
                  );
                },
              ),
            ),
          ),

          // ── Spodní ovládání ────────────────────────────────────────────────
          _buildControls(tutorState),
        ],
      ),
    );
  }

  Widget _buildControls(VoiceTutorState tutorState) {
    final isIdle = tutorState.status == TutorState.idle ||
        tutorState.status == TutorState.error;
    final isPaused = tutorState.status == TutorState.paused;
    final isActive = !isIdle;
    final isLiveSession = tutorState.status == TutorState.listening ||
        tutorState.status == TutorState.speaking ||
        tutorState.status == TutorState.thinking;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PAUSE / RESUME (zobrazí se jen během aktivního hovoru)
          if (isActive)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.0,
              child: _buildSecondaryButton(
                heroTag: 'pause_btn',
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: AppTheme.warning,
                onPressed: () {
                  final notifier =
                      ref.read(voiceTutorAgentProvider.notifier);
                  if (isPaused) {
                    notifier.resumeSession();
                  } else {
                    notifier.pauseSession();
                  }
                },
              ),
            ),

          if (isActive) const SizedBox(width: 20),

          // HLAVNÍ MIC / STOP tlačítko
          _buildMainButton(
            isIdle: isIdle,
            onPressed: () {
              final notifier = ref.read(voiceTutorAgentProvider.notifier);
              if (isIdle) {
                notifier.startSession();
              } else {
                notifier.stopSession();
              }
            },
          ),

          // ZMĚNIT TÉMA (jen při aktivní session)
          if (isLiveSession) ...[
            const SizedBox(width: 20),
            _buildSecondaryButton(
              heroTag: 'topic_btn',
              icon: Icons.shuffle_rounded,
              color: AppTheme.primary,
              onPressed: () {
                ref.read(voiceTutorAgentProvider.notifier).forceTopicChange();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Změna tématu odeslána...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Změnit téma',
            ),
          ],
        ],
      ),
    );
  }

  /// Hlavní velké tlačítko (mic / stop) s glow efektem
  Widget _buildMainButton({
    required bool isIdle,
    required VoidCallback onPressed,
  }) {
    final buttonColor = isIdle ? AppTheme.primary : AppTheme.error;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          isIdle ? Icons.mic_rounded : Icons.stop_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Sekundární tlačítko (pause, topic change)
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }

  // ── Pomocné metody ──────────────────────────────────────────────────────────

  List<ChatMessage> _getVisibleMessages(VoiceTutorState state) =>
      state.messages;

  int _getVisibleItemCount(VoiceTutorState state) =>
      state.messages.length + (state.currentTranscript.isNotEmpty ? 1 : 0);

  Widget _buildLiveTranscript(String transcript) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppTheme.speaking.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
              color: AppTheme.speaking.withValues(alpha: 0.25)),
        ),
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
            // Zobrazujeme celý transcript bez ořezávání — auto-scroll
            // zajistí, že uživatel vždy vidí nejnovější text.
            Text(
              transcript,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.onBackground,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser
                ? AppTheme.primary.withValues(alpha: 0.25)
                : AppTheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.onBackground,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
