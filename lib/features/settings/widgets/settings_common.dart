import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';

/// Nadpis sekce nastavení (verzálkami nad kartou).
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedTextColor(context),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Ikona položky nastavení v jemně podbarveném čtverečku.
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double backgroundAlpha;

  const SettingsIcon(this.icon, this.color, {super.key, this.backgroundAlpha = 0.08});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
