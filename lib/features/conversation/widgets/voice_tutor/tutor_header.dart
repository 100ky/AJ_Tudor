import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../services/agents/voice_tutor_agent.dart';
import '../fluid_voice_wave.dart';

/// Popisky stavů tutora pro UI.
extension TutorStateLabels on TutorState {
  /// Klíč pro [AppTheme.orbColorForState] a animaci vlny.
  String get orbKey => name;

  /// Stavový text pod vlnou (prázdný v klidu).
  String get statusText {
    switch (this) {
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
}

/// Adaptivní hlavička: v klidu velký banner s vlnou, během hovoru úzká lišta.
class TutorHeader extends StatelessWidget {
  final VoiceTutorState tutorState;
  final Color waveColor;
  final Stream<double>? activeVolumeStream;
  final bool isIdle;

  /// Zruší vybraný scénář nebo volný režim.
  final VoidCallback onClearScenario;

  /// Ztiší mluvícího tutora (klepnutí na vlnu během hovoru).
  final VoidCallback onInterruptTutor;

  const TutorHeader({
    super.key,
    required this.tutorState,
    required this.waveColor,
    required this.activeVolumeStream,
    required this.isIdle,
    required this.onClearScenario,
    required this.onInterruptTutor,
  });

  @override
  Widget build(BuildContext context) {
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
              ? _HeroHeader(
                  key: const ValueKey('hero_header'),
                  tutorState: tutorState,
                  waveColor: waveColor,
                  activeVolumeStream: activeVolumeStream,
                  onClearScenario: onClearScenario,
                )
              : _CompactHeader(
                  key: const ValueKey('compact_header'),
                  tutorState: tutorState,
                  waveColor: waveColor,
                  activeVolumeStream: activeVolumeStream,
                  onClearScenario: onClearScenario,
                  onInterruptTutor: onInterruptTutor,
                ),
        ),
      ),
    );
  }
}

/// Klidový stav: velký banner s vlnou, stav a aktivní režim.
class _HeroHeader extends StatelessWidget {
  final VoiceTutorState tutorState;
  final Color waveColor;
  final Stream<double>? activeVolumeStream;
  final VoidCallback onClearScenario;

  const _HeroHeader({
    super.key,
    required this.tutorState,
    required this.waveColor,
    required this.activeVolumeStream,
    required this.onClearScenario,
  });

  @override
  Widget build(BuildContext context) {
    final status = tutorState.status;
    final isOffline = status == TutorState.idle || status == TutorState.error;

    return Container(
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
                  color: isOffline ? AppTheme.onSurfaceMuted : AppTheme.success,
                  boxShadow: !isOffline
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
                stateLabel: status.orbKey,
                volumeStream: activeVolumeStream,
                height: 105,
                isCompact: false,
                showAmbientGlow: true,
              ),
            ),
          ),

          // Stavový text (zobrazen pouze pokud má text, např. chyba)
          if (status.statusText.isNotEmpty) ...[
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                status.statusText,
                key: ValueKey(status),
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
              deleteIcon:
                  Icon(Icons.close_rounded, size: 14, color: AppTheme.onSurfaceMuted),
              onDeleted: () {
                HapticFeedback.lightImpact();
                onClearScenario();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Aktivní hovor: vlna přes celou úzkou lištu, případně odznak role-play.
class _CompactHeader extends StatelessWidget {
  final VoiceTutorState tutorState;
  final Color waveColor;
  final Stream<double>? activeVolumeStream;
  final VoidCallback onClearScenario;
  final VoidCallback onInterruptTutor;

  const _CompactHeader({
    super.key,
    required this.tutorState,
    required this.waveColor,
    required this.activeVolumeStream,
    required this.onClearScenario,
    required this.onInterruptTutor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                if (tutorState.status == TutorState.speaking) onInterruptTutor();
              },
              child: FluidVoiceWave(
                color: waveColor,
                stateLabel: tutorState.status.orbKey,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor(context).withValues(alpha: 0.70),
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
                        onClearScenario();
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
}
