import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Skupina řádků na jednom povrchu, oddělených tenkou čarou (jako v systémovém nastavení).
class GroupedSection extends StatelessWidget {
  /// Řádky skupiny; čáru mezi ně vloží skupina sama.
  final List<Widget> children;

  /// Okraj kolem skupiny.
  final EdgeInsetsGeometry margin;

  /// Odsazení čáry zleva, aby začínala pod textem a ne pod ikonou.
  final double dividerIndent;

  const GroupedSection({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.dividerIndent = 16,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, indent: dividerIndent, color: AppTheme.hairline));
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );
  }
}

/// Nadpis sekce s nepovinným vysvětlením pod ním.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.font(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, letterSpacing: -0.4),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Malý popisek nad skupinou (např. den v historii, „Druh hovoru“).
class GroupLabel extends StatelessWidget {
  final String text;

  const GroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(text, style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
    );
  }
}

/// Nadpis obrazovky (velký, zarovnaný doleva).
class ScreenTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const ScreenTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTheme.font(fontSize: 32, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, letterSpacing: -0.8, height: 1.15),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
