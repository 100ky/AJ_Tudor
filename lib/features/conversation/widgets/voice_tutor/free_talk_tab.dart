import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';

/// Záložka „Volný“: spontánní rozhovor bez scénáře.
class FreeTalkTab extends StatelessWidget {
  /// Zruší volný režim a vrátí se k tématu z historie.
  final VoidCallback onCancel;

  const FreeTalkTab({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      color: AppTheme.accent.withValues(alpha: 0.06),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'SPONTÁNNÍ ROZHOVOR',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Volný pokec o čemkoliv',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Žádný konkrétní scénář ani předem dané téma. Přirozený přátelský rozhovor v angličtině o tom, co tě zrovna napadne.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppTheme.surfaceTextColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aktivní pro příští hovor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCancel();
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Zrušit a zpět', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
