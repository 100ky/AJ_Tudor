import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';

/// Hlavička karty agenta: ikona, název, popis a stavový odznak.
class AgentCardHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget badge;

  const AgentCardHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context)),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppTheme.mutedTextColor(context)),
              ),
            ],
          ),
        ),
        badge,
      ],
    );
  }
}

/// Stavový odznak agenta (např. „AKTIVNÍ“), volitelně s pulzující tečkou.
class AgentStatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool showPulse;

  const AgentStatusBadge(this.text, this.color, {super.key, this.showPulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
