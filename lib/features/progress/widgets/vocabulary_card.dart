import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import 'collapsible_card.dart';

/// Slovní zásoba studenta jako mrak štítků.
class VocabularyCard extends StatelessWidget {
  final List<String> vocabulary;
  final bool expanded;
  final VoidCallback onToggle;

  const VocabularyCard({
    super.key,
    required this.vocabulary,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleCard(
      title: 'Slovní zásoba',
      trailing: [CardBadge('${vocabulary.length} slov')],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        if (vocabulary.isEmpty)
          const EmptyStateCard('Zatím nemáš uložená žádná slovíčka.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vocabulary
                .map((word) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.glassLightColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.glassBorderColor(context),
                        ),
                      ),
                      child: Text(
                        word,
                        style: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
