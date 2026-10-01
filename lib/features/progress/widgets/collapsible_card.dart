import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Rozbalovací karta přehledu pokroku.
///
/// Hlavička (ikona, nadpis, odznaky, šipka) přepíná [expanded] přes [onToggle];
/// [children] se zobrazí jen v rozbaleném stavu. Stav rozbalení drží obrazovka,
/// aby přetrval i přepnutí záložek.
class CollapsibleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final List<Widget> trailing;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Color? backgroundColor;
  final BoxBorder? border;

  const CollapsibleCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing = const [],
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: titleColor ?? AppTheme.textColor(context),
      ),
    );

    return GlassContainer(
      color: backgroundColor,
      border: border,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: subtitle == null
                      ? titleText
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleText,
                            Text(
                              subtitle!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppTheme.mutedTextColor(context),
                              ),
                            ),
                          ],
                        ),
                ),
                ...trailing,
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.mutedTextColor(context),
                  size: 20,
                ),
              ],
            ),
          ),
          if (expanded) ...children,
        ],
      ),
    );
  }
}

/// Malý barevný odznak v hlavičce karty (např. „12 slov“).
class CardBadge extends StatelessWidget {
  final String text;
  final Color color;
  final FontWeight fontWeight;

  /// Výraznější varianta se silnějším pozadím a orámováním.
  final bool outlined;

  const CardBadge(
    this.text, {
    super.key,
    required this.color,
    this.fontWeight = FontWeight.w700,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: outlined ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.25)) : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }
}

/// Prázdný stav uvnitř karty přehledu.
class EmptyStateCard extends StatelessWidget {
  final String message;

  const EmptyStateCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurfaceMuted,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
