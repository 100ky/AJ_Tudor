import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/database/app_database.dart';

/// Podrobnosti „Scénář“: nabídnuté role-play scénáře a vlastní scénář na přání.
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

  void _generate() {
    HapticFeedback.lightImpact();
    onGenerateScenarios();
  }

  @override
  Widget build(BuildContext context) {
    final generateButton = TextButton.icon(
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      onPressed: isGeneratingScenarios ? null : _generate,
      icon: isGeneratingScenarios
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(scenarios.isEmpty ? Icons.auto_awesome_rounded : Icons.refresh_rounded, size: 18),
      label: Text(isGeneratingScenarios
          ? 'Plánuji scénáře...'
          : scenarios.isEmpty
              ? 'Vygenerovat scénáře na míru'
              : 'Přeplánovat'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scenarios.isEmpty)
          Text(
            'Zatím nemáš připravené scénáře. Nech si je vygenerovat, nebo popiš vlastní situaci.',
            style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.45),
          )
        else
          for (final s in scenarios)
            ScenarioCard(
              scenario: s,
              isSelected: selectedScenarioId == s.id,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleScenario(s, selectedScenarioId == s.id);
              },
            ),
        generateButton,
        const SizedBox(height: 6),
        CustomScenarioInput(
          controller: customScenarioController,
          isCreating: isCreatingCustomScenario,
          onCreate: onCreateCustomScenario,
        ),
      ],
    );
  }
}

/// Jeden role-play scénář: výběr, název, obtížnost a popis.
class ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final bool isSelected;
  final VoidCallback onTap;

  const ScenarioCard({super.key, required this.scenario, required this.isSelected, required this.onTap});

  static String _difficulty(String value) => switch (value.toLowerCase()) {
        'easy' => 'lehký',
        'medium' => 'střední',
        'hard' => 'těžký',
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: scenario.title,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: '  ${_difficulty(scenario.difficulty)}'),
                      ]),
                      style: AppTheme.font(fontSize: 15, color: AppTheme.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scenario.description,
                      style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zadání vlastního scénáře na přání.
class CustomScenarioInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isCreating;
  final VoidCallback onCreate;

  const CustomScenarioInput({super.key, required this.controller, required this.isCreating, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vlastní scénář', style: AppTheme.font(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 1,
          style: AppTheme.font(fontSize: 14.5, color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Popiš situaci, např. pohovor v IT firmě nebo reklamace v obchodě',
            fillColor: AppTheme.surfaceRaised,
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: isCreating ? null : onCreate,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: isCreating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background))
                : const Text('Vytvořit a vybrat'),
          ),
        ),
      ],
    );
  }
}
