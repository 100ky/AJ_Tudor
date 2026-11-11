import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';

/// Společný vzhled pruhů pod přepisem: tmavý povrch, popisek, text a křížek.
class _Strip extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismiss;
  final String dismissLabel;

  const _Strip({super.key, required this.child, this.onDismiss, this.dismissLabel = 'Skrýt'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, onDismiss == null ? 16 : 4, 10),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(child: child),
            if (onDismiss != null)
              IconButton(
                tooltip: dismissLabel,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onDismiss!();
                },
                icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  final String label;
  final String text;
  final IconData? icon;

  static const Color labelColor = AppTheme.textSecondary;

  const _LabeledText({required this.label, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: labelColor), const SizedBox(width: 5)],
            Text(label, style: AppTheme.font(fontSize: 12.5, fontWeight: FontWeight.w500, color: labelColor)),
          ],
        ),
        const SizedBox(height: 2),
        Text(text, style: AppTheme.font(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.35)),
      ],
    );
  }
}

/// Chybová zpráva hlasového tutora (např. nedostupný mikrofon).
class TutorErrorBanner extends StatelessWidget {
  final String message;

  const TutorErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return _Strip(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppTheme.font(color: AppTheme.textPrimary, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Nenápadná nápověda s doporučenou frází / otázkou od Voice Directora.
class DirectorTipBanner extends StatelessWidget {
  final String tip;
  final VoidCallback onDismiss;

  const DirectorTipBanner({super.key, required this.tip, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _Strip(
        key: ValueKey('director_tip_$tip'),
        onDismiss: onDismiss,
        dismissLabel: 'Skrýt nápovědu',
        child: _LabeledText(label: 'Nápověda', text: tip, icon: Icons.lightbulb_outline_rounded),
      ),
    );
  }
}

/// Průběh lekce s kartičkami během hovoru („Lekce: 3/10 výrazů“).
class LessonProgressBanner extends StatelessWidget {
  final int completed;
  final int total;
  final bool finished;

  const LessonProgressBanner({super.key, required this.completed, required this.total, required this.finished});

  @override
  Widget build(BuildContext context) {
    final label = finished ? 'Lekce hotová: $completed z $total' : 'Lekce: $completed/$total výrazů';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          Text(
            label,
            style: AppTheme.font(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: finished ? AppTheme.success : AppTheme.textPrimary,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : completed / total,
                minHeight: 4,
                color: finished ? AppTheme.success : AppTheme.textPrimary,
                backgroundColor: AppTheme.surfaceHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Věta, kterou má student po opravě chyby zopakovat.
class RepeatTargetBanner extends StatelessWidget {
  final String sentence;
  final VoidCallback onDismiss;

  const RepeatTargetBanner({super.key, required this.sentence, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _Strip(
        key: ValueKey('repeat_target_$sentence'),
        onDismiss: onDismiss,
        child: _LabeledText(label: 'Zopakuj nahlas', text: sentence, icon: Icons.record_voice_over_rounded),
      ),
    );
  }
}
