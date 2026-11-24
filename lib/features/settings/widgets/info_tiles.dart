import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        leading: const SettingsIcon(Icons.smart_toy_rounded, AppTheme.textSecondary),
        title: Text(
          'Správa a přehled AI agentů',
          style: AppTheme.font(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          'Tutor, Analytik skóre a Plánovač témat na míru',
          style: AppTheme.font(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
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
          const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text('Verze', style: AppTheme.font(color: AppTheme.textPrimary)),
          const Spacer(),
          Text(
            '0.1.0 - Dev Preview',
            style: AppTheme.font(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
