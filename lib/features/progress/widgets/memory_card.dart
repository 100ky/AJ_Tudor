import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import 'collapsible_card.dart';

/// Dlouhodobá paměť tutora (briefing z poslední analýzy lekce).
class MemoryCard extends StatelessWidget {
  final String briefing;
  final bool expanded;
  final VoidCallback onToggle;

  const MemoryCard({
    super.key,
    required this.briefing,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleCard(
      title: 'Co si o tobě Tudor pamatuje',
      expanded: expanded,
      onToggle: onToggle,
      children: [
        Text(
          briefing,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: AppTheme.surfaceTextColor(context),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
