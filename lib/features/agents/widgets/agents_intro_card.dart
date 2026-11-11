import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Úvodní karta obrazovky agentů.
class AgentsIntroCard extends StatelessWidget {
  const AgentsIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Row(
        children: [
          const Icon(Icons.diversity_3, size: 28, color: AppTheme.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-agentní systém AJ Tudor',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tři specializovaní AI agenti spolupracují na tvé výuce angličtiny.',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: AppTheme.mutedTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
