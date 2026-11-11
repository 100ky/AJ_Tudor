import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/grouped_section.dart';
import '../../../../services/agents/voice_tutor_agent.dart';

/// Druh hovoru před zahájením.
enum TopicMode {
  /// Téma připravené z historie.
  history,

  /// Role-play scénář.
  scenarios,

  /// Volný rozhovor.
  freeTalk,

  /// Lekce s dnešními kartičkami.
  lesson,
}

/// Výběr druhu hovoru: seznam čtyř druhů, vybraný se rozbalí s podrobnostmi.
class SessionSetupView extends StatelessWidget {
  final TopicMode activeMode;
  final ValueChanged<TopicMode> onModeChanged;

  /// Podrobnosti vybraného druhu (téma, kartičky, scénáře); null = bez podrobností.
  final Widget? tabContent;

  const SessionSetupView({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
    required this.tabContent,
  });

  static const _modes = [
    (TopicMode.history, 'Téma z historie', 'Navazuje na minulé hovory', Icons.lightbulb_outline_rounded),
    (
      TopicMode.lesson,
      'Lekce s kartičkami',
      'Až ${VoiceTutorAgent.lessonCardCount} výrazů z dnešních kartiček, do ${VoiceTutorAgent.lessonMinutes} min',
      Icons.school_outlined
    ),
    (TopicMode.scenarios, 'Scénář', 'Role-play podle situace', Icons.theater_comedy_outlined),
    (TopicMode.freeTalk, 'Volný pokec', 'Bez tématu, o čem chceš', Icons.chat_bubble_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const GroupLabel('Druh hovoru'),
        GroupedSection(
          dividerIndent: 54,
          children: [
            for (final (mode, title, subtitle, icon) in _modes)
              _ModeRow(
                title: title,
                subtitle: subtitle,
                icon: icon,
                selected: mode == activeMode,
                onTap: () {
                  if (mode == activeMode) return;
                  HapticFeedback.selectionClick();
                  onModeChanged(mode);
                },
                detail: mode == activeMode ? tabContent : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? detail;

  const _ModeRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: selected ? AppTheme.textPrimary : AppTheme.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTheme.font(fontSize: 15.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          if (detail == null)
                            Text(subtitle, style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check_rounded, size: 22, color: AppTheme.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 0, 16, 14),
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: detail),
          ),
      ],
    );
  }
}
