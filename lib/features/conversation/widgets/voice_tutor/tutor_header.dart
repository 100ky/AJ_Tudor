import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/grouped_section.dart';
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

/// Hlavička obrazovky Hovor: v klidu nadpis a klidná vlna, během hovoru název
/// hovoru, velká vlna přes celou šířku a stav pod ní.
class TutorHeader extends StatelessWidget {
  final VoiceTutorState tutorState;
  final Color waveColor;
  final Stream<double>? activeVolumeStream;
  final bool isIdle;

  /// Název probíhajícího hovoru (téma, scénář, lekce).
  final String title;

  /// Ztiší mluvícího tutora (klepnutí na vlnu během hovoru).
  final VoidCallback onInterruptTutor;

  const TutorHeader({
    super.key,
    required this.tutorState,
    required this.waveColor,
    required this.activeVolumeStream,
    required this.isIdle,
    required this.title,
    required this.onInterruptTutor,
  });

  @override
  Widget build(BuildContext context) {
    final status = tutorState.status;
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: isIdle ? _idle(status) : _active(status),
    );
  }

  Widget _idle(TutorState status) {
    return Column(
      key: const ValueKey('hero_header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenTitle('Hovor'),
        const SizedBox(height: 4),
        FluidVoiceWave(
          color: waveColor,
          stateLabel: status.orbKey,
          volumeStream: activeVolumeStream,
          height: 96,
          isCompact: false,
          showAmbientGlow: true,
        ),
        if (status.statusText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              status.statusText,
              textAlign: TextAlign.center,
              style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.stateTextColor(status.orbKey)),
            ),
          ),
      ],
    );
  }

  Widget _active(TutorState status) {
    final speaking = status == TutorState.speaking;
    return Column(
      key: const ValueKey('compact_header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.font(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ),
        Semantics(
          button: speaking,
          label: speaking ? 'Ztišit tutora' : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: speaking ? onInterruptTutor : null,
            child: FluidVoiceWave(
              color: waveColor,
              stateLabel: status.orbKey,
              volumeStream: activeVolumeStream,
              height: 128,
              isCompact: false,
              showAmbientGlow: true,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(status),
            children: [
              Text(
                status.statusText,
                textAlign: TextAlign.center,
                style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.stateTextColor(status.orbKey)),
              ),
              Text(
                speaking ? 'Klepnutím na vlnu ho ztišíš' : '',
                textAlign: TextAlign.center,
                style: AppTheme.font(fontSize: 12.5, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
