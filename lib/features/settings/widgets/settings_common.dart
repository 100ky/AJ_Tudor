import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Nadpis sekce nastavení (malým šedým písmem nad skupinou).
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
    );
  }
}

/// Ikona položky nastavení: obrysová, šedá, bez podbarvení.
///
/// [color] a [backgroundAlpha] zůstaly kvůli starším voláním, barva se už nepoužívá.
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double backgroundAlpha;

  const SettingsIcon(this.icon, this.color, {super.key, this.backgroundAlpha = 0.08});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Icon(icon, color: AppTheme.textSecondary, size: 22),
    );
  }
}
