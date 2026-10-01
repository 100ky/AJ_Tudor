import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../services/agents/voice_tutor_agent.dart';

/// Spodní ovládací panel hovoru: pauza, mikrofon / stop a změna tématu.
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
    final isPaused = status == TutorState.paused;
    final isLiveSession = status == TutorState.listening ||
        status == TutorState.speaking ||
        status == TutorState.thinking;
    final canChangeTopic = isLiveSession && status != TutorState.thinking;

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
            _SecondaryButton(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: AppTheme.warning,
              tooltip: isPaused ? 'Pokračovat' : 'Pozastavit',
              onPressed: () {
                HapticFeedback.lightImpact();
                onTogglePause();
              },
            ),

          if (isActive) const SizedBox(width: 24),

          // HLAVNÍ TLAČÍTKO (MIC / STOP)
          _MainButton(
            isIdle: isIdle,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onMainPressed();
            },
          ),

          // ZMĚNIT TÉMA (jen při aktivní session)
          if (isActive) ...[
            const SizedBox(width: 24),
            _SecondaryButton(
              icon: Icons.shuffle_rounded,
              color: canChangeTopic ? AppTheme.primary : AppTheme.onSurfaceMuted,
              tooltip: 'Změnit téma',
              onPressed: canChangeTopic
                  ? () {
                      HapticFeedback.selectionClick();
                      onChangeTopic();
                    }
                  : () {},
            ),
          ],
        ],
      ),
    );
  }
}

/// Hlavní velké tlačítko (mic / stop) s gradientem a glow efektem.
class _MainButton extends StatelessWidget {
  final bool isIdle;
  final VoidCallback onPressed;

  const _MainButton({required this.isIdle, required this.onPressed});

  @override
  Widget build(BuildContext context) {
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
              color: (isIdle ? AppTheme.primary : AppTheme.error).withValues(alpha: 0.4),
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
}

/// Sekundární tlačítko (pauza, změna tématu) ve skleněném stylu.
class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _SecondaryButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
}
