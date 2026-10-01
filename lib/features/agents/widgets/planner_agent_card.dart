import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/app_database.dart';
import 'agent_card_header.dart';

/// Karta plánovače scénářů: nabídnuté scénáře, nové plánování a vlastní téma.
class PlannerAgentCard extends StatelessWidget {
  final List<Scenario> scenarios;
  final int? selectedScenarioId;
  final bool isPlanning;
  final bool isCreatingCustom;
  final TextEditingController customTopicController;
  final VoidCallback onPlanScenarios;
  final VoidCallback onCreateCustomScenario;
  final ValueChanged<Scenario> onSelectScenario;

  const PlannerAgentCard({
    super.key,
    required this.scenarios,
    required this.selectedScenarioId,
    required this.isPlanning,
    required this.isCreatingCustom,
    required this.customTopicController,
    required this.onPlanScenarios,
    required this.onCreateCustomScenario,
    required this.onSelectScenario,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentCardHeader(
            icon: Icons.auto_awesome,
            color: AppTheme.accent,
            title: '3. Plánovač témat',
            subtitle: 'Agent vytvářející scénáře na základě chyb',
            badge: AgentStatusBadge(
              isPlanning ? 'PLÁNUJE...' : 'PŘIPRAVEN',
              isPlanning ? AppTheme.warning : AppTheme.accent,
            ),
          ),
          Divider(color: AppTheme.outlineLightColor(context), height: 24),
          Text(
            'Aktuální scénáře na míru:',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 10),
          if (scenarios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Zatím nejsou naplánovány žádné scénáře. Klikni na tlačítko níže.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.mutedTextColor(context)),
              ),
            )
          else
            Column(
              children: scenarios
                  .map((s) => _MiniScenarioTile(
                        scenario: s,
                        isSelected: selectedScenarioId == s.id,
                        onTap: () => onSelectScenario(s),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isPlanning ? null : onPlanScenarios,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: isPlanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(isPlanning
                  ? 'Plánování nových témat...'
                  : 'Vymyslet nová témata'),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppTheme.outlineLightColor(context)),
          const SizedBox(height: 12),
          Text(
            'Nebo napiš své vlastní téma:',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customTopicController,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textColor(context), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Napiš téma (např. „objednávka v restauraci")...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.mutedTextColor(context), fontSize: 13),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: isCreatingCustom
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => onCreateCustomScenario(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isCreatingCustom ? null : onCreateCustomScenario,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniScenarioTile extends StatelessWidget {
  final Scenario scenario;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniScenarioTile({
    required this.scenario,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : (isDark ? AppTheme.glassLightDark : AppTheme.glassLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.4)
              : (isDark ? AppTheme.outlineDark : AppTheme.outline),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.label_important_outline,
                color: AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context)),
                    ),
                    Text(
                      scenario.description,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.mutedTextColor(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : (isDark
                          ? AppTheme.backgroundSecondaryDark
                          : AppTheme.backgroundSecondary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSelected ? 'AKTIVNÍ' : scenario.difficulty.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.mutedTextColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
