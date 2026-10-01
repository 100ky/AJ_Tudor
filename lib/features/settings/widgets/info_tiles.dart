import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../agents/agents_screen.dart';
import 'settings_common.dart';

/// Odkaz na obrazovku s přehledem AI agentů.
class AgentsLinkTile extends StatelessWidget {
  const AgentsLinkTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SettingsIcon(Icons.smart_toy_rounded, AppTheme.primary,
            backgroundAlpha: 0.1),
        title: Text('Správa a přehled AI agentů',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context))),
        subtitle: Text('Tutor, Analytik skóre a Plánovač témat na míru',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppTheme.mutedTextColor(context))),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgentsScreen()),
          );
        },
      ),
    );
  }
}

/// Verze aplikace.
class AppInfoCard extends StatelessWidget {
  const AppInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.mutedTextColor(context), size: 20),
          const SizedBox(width: 12),
          Text('Verze',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textColor(context))),
          const Spacer(),
          Text('0.1.0 - Dev Preview',
              style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context), fontSize: 13)),
        ],
      ),
    );
  }
}
