import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/agents/voice_tutor_agent.dart';
import 'agent_card_header.dart';

/// Karta konverzačního tutora s jeho aktuálním stavem.
class TutorAgentCard extends StatelessWidget {
  final TutorState status;

  const TutorAgentCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status != TutorState.idle && status != TutorState.error;

    Color statusColor;
    String statusText;
    switch (status) {
      case TutorState.listening:
        statusColor = AppTheme.success;
        statusText = 'Poslouchá tě...';
        break;
      case TutorState.speaking:
        statusColor = AppTheme.speaking;
        statusText = 'Právě mluví...';
        break;
      case TutorState.thinking:
        statusColor = AppTheme.primary;
        statusText = 'Přemýšlí...';
        break;
      case TutorState.connecting:
      case TutorState.reconnecting:
        statusColor = AppTheme.warning;
        statusText = 'Připojuje se...';
        break;
      case TutorState.paused:
        statusColor = AppTheme.warning;
        statusText = 'Pozastaven';
        break;
      case TutorState.error:
        statusColor = AppTheme.error;
        statusText = 'Chyba spojení';
        break;
      case TutorState.idle:
        statusColor = AppTheme.mutedTextColor(context);
        statusText = 'V POHOTOVOSTI';
    }

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentCardHeader(
            icon: Icons.record_voice_over,
            color: AppTheme.primary,
            title: '1. Konverzační Tutor',
            subtitle: 'Agent zodpovědný za přátelskou diskuzi',
            badge: AgentStatusBadge(statusText, statusColor, showPulse: isActive),
          ),
          Divider(color: AppTheme.outlineLightColor(context), height: 24),
          Text(
            'Osobnost a styl:',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 6),
          Text(
            '• AJ Tudor je rodilý mluvčí z Velké Británie, který momentálně žije v České republice.\n'
            '• NEBUDE tě jen vyslýchat! Rád reaguje, sdílí vlastní historky o svém dni, vaření, výletech nebo o tom, jak zápasí s češtinou.\n'
            '• Mluví pomalu a přizpůsobuje slova tvé úrovni angličtiny.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.5,
                color: AppTheme.mutedTextColor(context)),
          ),
        ],
      ),
    );
  }
}
