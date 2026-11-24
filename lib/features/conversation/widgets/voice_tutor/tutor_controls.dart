import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../services/agents/voice_tutor_agent.dart';

/// Spodní ovládání: během hovoru Pauza, Ukončit a Jiné téma (v klidu se hovor spouští z navigace).
class TutorControls extends StatelessWidget {
  final TutorState status;
  final bool isIdle;
  final bool isActive;
  final VoidCallback onTogglePause;
  final VoidCallback onMainPressed;
  final VoidCallback onChangeTopic;

  const TutorControls({
    super.key,
    required this.status,
    required this.isIdle,
    required this.isActive,
    required this.onTogglePause,
    required this.onMainPressed,
    required this.onChangeTopic,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    final isPaused = status == TutorState.paused;
    // Lekce se ukončuje (ukládají se poslední repliky): tlačítka už nic nedělají
    final isEnding = status == TutorState.ending;
    final isLiveSession =
        status == TutorState.listening || status == TutorState.speaking || status == TutorState.thinking;
    final canChangeTopic = isLiveSession && status != TutorState.thinking;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 12, 28, 24 + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _RoundButton(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: isPaused ? 'Pokračovat' : 'Pauza',
              onPressed: isEnding
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onTogglePause();
                    },
            ),
          ),
          Expanded(
            child: _RoundButton(
              icon: Icons.stop_rounded,
              label: isEnding ? 'Ukončuji…' : 'Ukončit',
              size: 72,
              background: isEnding ? AppTheme.surfaceRaised : AppTheme.danger,
              foreground: Colors.white,
              onPressed: isEnding
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onMainPressed();
                    },
            ),
          ),
          Expanded(
            child: _RoundButton(
              icon: Icons.shuffle_rounded,
              label: 'Jiné téma',
              onPressed: canChangeTopic
                  ? () {
                      HapticFeedback.selectionClick();
                      onChangeTopic();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kulaté tlačítko s popiskem pod ním.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final Color background;
  final Color foreground;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 58,
    this.background = AppTheme.surfaceRaised,
    this.foreground = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Středy tlačítek i popisky leží na jedné čáře
            SizedBox(height: (72 - size) / 2),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: background),
              child: Icon(icon, size: size > 58 ? 30 : 26, color: enabled ? foreground : AppTheme.textTertiary),
            ),
            SizedBox(height: (72 - size) / 2 + 6),
            Text(
              label,
              style: AppTheme.font(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: enabled ? AppTheme.textSecondary : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
