import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../services/agents/voice_tutor_agent.dart';

/// Spodní ovládání: v klidu tlačítko Začít hovor, během hovoru Pauza, Ukončit a Jiné téma.
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
    if (!isActive) return _StartButton(onPressed: onMainPressed);

    final isPaused = status == TutorState.paused;
    final isLiveSession =
        status == TutorState.listening || status == TutorState.speaking || status == TutorState.thinking;
    final canChangeTopic = isLiveSession && status != TutorState.thinking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _RoundButton(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: isPaused ? 'Pokračovat' : 'Pauza',
              onPressed: () {
                HapticFeedback.lightImpact();
                onTogglePause();
              },
            ),
          ),
          Expanded(
            child: _RoundButton(
              icon: Icons.stop_rounded,
              label: 'Ukončit',
              size: 72,
              background: AppTheme.danger,
              foreground: Colors.white,
              onPressed: () {
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

/// Tlačítko Začít hovor pod výběrem druhu hovoru.
class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onPressed();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.surfaceRaised,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: AppTheme.font(fontSize: 16.5, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.mic_rounded, size: 24),
              label: const Text('Začít hovor'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Po hovoru Tudor lekci rozebere a z chyb udělá kartičky.',
            textAlign: TextAlign.center,
            style: AppTheme.font(fontSize: 12.5, color: AppTheme.textTertiary),
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
