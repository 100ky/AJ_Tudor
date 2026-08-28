import 'dart:ui';
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
            // ── Adaptivní hlavička (přechod mezi Hero a Compact režimem) ───────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 350),
              firstCurve: Curves.easeInOutCubic,
              secondCurve: Curves.easeInOutCubic,
              crossFadeState: isIdle
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildHeroHeader(
                tutorState: tutorState,
                stateLabel: stateLabel,
                orbColor: orbColor,
                activeVolumeStream: activeVolumeStream,
              ),
              secondChild: _buildCompactHeader(
                tutorState: tutorState,
                stateLabel: stateLabel,
                orbColor: orbColor,
                activeVolumeStream: activeVolumeStream,
              ),
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

  // ── Hero Header (Klidový stav / Idle) ──────────────────────────────────────
  Widget _buildHeroHeader({
    required VoiceTutorState tutorState,
    required String stateLabel,
    required Color orbColor,
    required Stream<double>? activeVolumeStream,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
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

          // Velký Liquid Orb
          Stack(
            alignment: Alignment.center,
            children: [
              LiquidVoiceOrb(
                color: orbColor,
                stateLabel: stateLabel,
                volumeStream: activeVolumeStream,
                size: 150,
              ),
              OrbStateIcon(
                stateLabel: stateLabel,
                color: orbColor,
                size: 34,
              ),
            ],
          ),

          const SizedBox(height: 10),

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
            const SizedBox(height: 8),
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
              backgroundColor: AppTheme.accent.withValues(alpha: 0.08),
              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.25)),
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
    );
  }

  // ── Kompaktní Header (Aktivní hovor) ───────────────────────────────────────
  Widget _buildCompactHeader({
    required VoiceTutorState tutorState,
    required String stateLabel,
    required Color orbColor,
    required Stream<double>? activeVolumeStream,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.glass,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.outline.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Mini Liquid Orb
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    LiquidVoiceOrb(
                      color: orbColor,
                      stateLabel: stateLabel,
                      volumeStream: activeVolumeStream,
                      size: 42,
                    ),
                    OrbStateIcon(
                      stateLabel: stateLabel,
                      color: orbColor,
                      size: 18,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Stavová pilulka
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: orbColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: orbColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: orbColor,
                              boxShadow: [
                                BoxShadow(
                                  color: orbColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _getStatusText(tutorState.status),
                              key: ValueKey(tutorState.status),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: orbColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Kompaktní Scenario badge
                    if (tutorState.selectedScenarioId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.25),
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
                            const SizedBox(width: 4),
                            Text(
                              'Roleplay',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Tlačítko pro rychlé přepnutí/odstranění scénáře
              if (tutorState.selectedScenarioId != null)
                GestureDetector(
                  onTap: () {
                    ref
                        .read(voiceTutorAgentProvider.notifier)
                        .selectScenario(0, '');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.backgroundSecondary,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.onSurfaceMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Prázdný stav před zahájením konverzace ─────────────────────────────────
  Widget _buildEmptyState(VoiceTutorState tutorState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.record_voice_over_rounded,
                size: 32,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Připraven k hlasové lekci',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stiskněte tlačítko mikrofonu a začněte mluvit anglicky. Tutor vás okamžitě uslyší.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
                height: 1.4,
              ),
            ),
          ],
        ),
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
                  Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.backgroundDark
                      : AppTheme.background,
                  (Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.backgroundDark
                          : AppTheme.background)
                      .withValues(alpha: 0.85),
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
              color: isLiveSession
                  ? AppTheme.primary
                  : AppTheme.onSurfaceMuted,
              tooltip: 'Změnit téma',
              onPressed: isLiveSession
                  ? () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(voiceTutorAgentProvider.notifier)
                          .forceTopicChange();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Změna tématu odeslána...'),
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
    return ChatBubble(
      text: msg.text,
      isUser: msg.isUser,
    );
  }
}
