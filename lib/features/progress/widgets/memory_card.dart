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
      backgroundColor: AppTheme.primary.withValues(alpha: 0.05),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      icon: Icons.psychology_rounded,
      color: AppTheme.primary,
      title: 'Co si tutor pamatuje',
      titleColor: AppTheme.primary,
      trailing: [
        CardBadge('Aktivní paměť', color: AppTheme.primary, fontWeight: FontWeight.w600),
      ],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        const SizedBox(height: 12),
        Text(
          briefing,
          style: GoogleFonts.plusJakartaSans(
            fontStyle: FontStyle.italic,
            fontSize: 13,
            color: AppTheme.surfaceTextColor(context),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
