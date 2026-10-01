import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';

/// Chybová zpráva hlasového tutora (např. nedostupný mikrofon).
class TutorErrorBanner extends StatelessWidget {
  final String message;

  const TutorErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.error.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
        shadows: const [],
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: GlassContainer(
          key: ValueKey('director_tip_$tip'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.primary.withValues(alpha: 0.10),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.30),
            width: 1,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDismiss();
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
