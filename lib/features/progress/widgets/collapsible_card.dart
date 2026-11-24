import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Rozbalovací řádek přehledu pokroku.
///
/// Hlavička (nadpis, podnadpis, hodnota vpravo, šipka) přepíná [expanded] přes [onToggle];
/// [children] se zobrazí jen v rozbaleném stavu. Stav rozbalení drží obrazovka,
/// aby přetrval i přepnutí záložek.
class CollapsibleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  /// Když je true, nekreslí vlastní [GlassContainer] (slouží pro vnoření do [GroupedSection]).
  final bool grouped;

  const CollapsibleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.grouped = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTheme.font(fontWeight: FontWeight.w500, fontSize: 15.5, color: AppTheme.textPrimary),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ...trailing,
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textTertiary, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    if (grouped) return content;
    return GlassContainer(padding: EdgeInsets.zero, child: content);
  }
}

/// Hodnota v hlavičce řádku (např. „12 slov“), šedým textem.
class CardBadge extends StatelessWidget {
  final String text;

  const CardBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, fontFeatures: AppTheme.tabularFigures),
    );
  }
}

/// Prázdný stav uvnitř rozbaleného řádku.
class EmptyStateCard extends StatelessWidget {
  final String message;

  const EmptyStateCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: AppTheme.font(color: AppTheme.textSecondary, fontSize: 14, height: 1.45),
      ),
    );
  }
}
