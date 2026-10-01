import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/database/app_database.dart';

/// Záložka „Scénáře“: vlastní scénář na přání a nabídnuté role-play scénáře.
class ScenariosTab extends StatelessWidget {
  final List<Scenario> scenarios;
  final int? selectedScenarioId;
  final bool isGeneratingScenarios;
  final VoidCallback onGenerateScenarios;

  /// Vybere scénář, nebo zruší výběr, pokud byl vybraný.
  final void Function(Scenario scenario, bool wasSelected) onToggleScenario;

  final TextEditingController customScenarioController;
  final bool isCreatingCustomScenario;
  final VoidCallback onCreateCustomScenario;

  const ScenariosTab({
    super.key,
    required this.scenarios,
    required this.selectedScenarioId,
    required this.isGeneratingScenarios,
    required this.onGenerateScenarios,
    required this.onToggleScenario,
    required this.customScenarioController,
    required this.isCreatingCustomScenario,
    required this.onCreateCustomScenario,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Vlastní promptované téma / příběh
        CustomScenarioInput(
          controller: customScenarioController,
          isCreating: isCreatingCustomScenario,
          onCreate: onCreateCustomScenario,
        ),
        const SizedBox(height: 14),

        if (scenarios.isEmpty)
          GlassContainer(
            key: const ValueKey('scenarios_empty'),
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                Icon(
                  Icons.theater_comedy_rounded,
                  size: 32,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  'Žádné předpřipravené scénáře',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vypromptuj si vlastní příběh výše, nebo si nech vygenerovat 3 scénáře na míru.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.mutedTextColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isGeneratingScenarios ? null : _generate,
                  icon: isGeneratingScenarios
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 15),
                  label: Text(isGeneratingScenarios
                      ? 'Plánuji scénáře...'
                      : 'Vygenerovat scénáře na míru'),
                ),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.theater_comedy_rounded, size: 14, color: AppTheme.accent),
                const SizedBox(width: 6),
                Text(
                  'ROLE-PLAY SCÉNÁŘE (${scenarios.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.accent,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: isGeneratingScenarios ? null : _generate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isGeneratingScenarios
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.8),
                              )
                            : Icon(Icons.refresh_rounded,
                                size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Přeplánovat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...scenarios.map((s) {
            final isSelected = selectedScenarioId == s.id;
            return ScenarioCard(
              scenario: s,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleScenario(s, isSelected);
              },
            );
          }),
        ],
      ],
    );
  }

  void _generate() {
    HapticFeedback.lightImpact();
    onGenerateScenarios();
  }
}

/// Karta role-play scénáře s obtížností a stavem výběru.
class ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final bool isSelected;
  final VoidCallback onTap;

  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? AppTheme.accent.withValues(alpha: isDark ? 0.22 : 0.08)
              : null,
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.55)
                : (isDark ? AppTheme.outlineDark : AppTheme.outline),
            width: isSelected ? 1.5 : 1.0,
          ),
          shadows: isSelected ? AppTheme.glassShadow : AppTheme.glassShadowLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.theater_comedy_rounded,
                      size: 15,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scenario.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DifficultyBadge(scenario.difficulty),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scenario.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.surfaceTextColor(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: isSelected ? AppTheme.accent : AppTheme.mutedTextColor(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSelected ? 'Vybráno pro příští hovor' : 'Klepnutím vybrat pro hovor',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.accent : AppTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = AppTheme.success;
        break;
      case 'medium':
        color = AppTheme.warning;
        break;
      case 'hard':
        color = AppTheme.error;
        break;
      default:
        color = AppTheme.onSurfaceMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Zadání vlastního příběhu / scénáře na přání.
class CustomScenarioInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isCreating;
  final VoidCallback onCreate;

  const CustomScenarioInput({
    super.key,
    required this.controller,
    required this.isCreating,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      color: AppTheme.accent.withValues(alpha: isDark ? 0.08 : 0.04),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'VLASTNÍ PŘÍBĚH / SCÉNÁŘ NA PŘÁNÍ ✍️',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 2,
            minLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textColor(context),
            ),
            decoration: InputDecoration(
              hintText:
                  'Popiš situaci... (např. Pohovor v IT firmě, nákup veterána v Londýně, hádka se sousedem)',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.mutedTextColor(context),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isCreating ? null : onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
              ),
              icon: isCreating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                isCreating ? 'Tvořím scénář...' : 'Vytvořit a aktivovat ✨',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
