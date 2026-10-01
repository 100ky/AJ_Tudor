import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/agents/voice_tutor_agent.dart';
import 'widgets/agents_intro_card.dart';
import 'widgets/analyzer_agent_card.dart';
import 'widgets/planner_agent_card.dart';
import 'widgets/topic_agent_card.dart';
import 'widgets/tutor_agent_card.dart';

/// Přehled AI agentů, jejich stavu a výsledků.
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  bool _isPlanningScenarios = false;
  bool _isCreatingCustom = false;
  final _customTopicController = TextEditingController();

  @override
  void dispose() {
    _customTopicController.dispose();
    super.dispose();
  }

  Future<void> _triggerScenarioPlanning() async {
    setState(() => _isPlanningScenarios = true);
    try {
      await ref.read(scenarioPlannerAgentProvider).planScenarios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Plánovač témat úspěšně vygeneroval 3 nové scénáře! 🎯')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při plánování scénářů: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPlanningScenarios = false);
      }
    }
  }

  Future<void> _createCustomScenario() async {
    final text = _customTopicController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isCreatingCustom = true);
    try {
      await ref.read(scenarioPlannerAgentProvider).planCustomScenario(text);
      if (mounted) {
        _customTopicController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Vlastní scénář „$text" úspěšně vytvořen! 🎯')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při vytváření scénáře: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingCustom = false);
      }
    }
  }

  void _selectScenario(Scenario scenario) {
    ref
        .read(voiceTutorAgentProvider.notifier)
        .selectScenario(scenario.id, scenario.tutorInstruction);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Scénář „${scenario.title}" vybrán! Můžeš spustit Voice. 🗣️')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final profile = ref.watch(userProfileProvider).value;
    final sessions = ref.watch(allSessionsProvider).value ?? const [];
    final lastSession = sessions.isNotEmpty ? sessions.first : null;
    final scenarios = ref.watch(availableScenariosProvider).value ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Moji AI Agenti',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const AgentsIntroCard(),
          const SizedBox(height: 20),
          TutorAgentCard(status: tutorState.status),
          const SizedBox(height: 16),
          AnalyzerAgentCard(
            profile: profile,
            lastSession: lastSession,
            tutorStatus: tutorState.status,
          ),
          const SizedBox(height: 16),
          PlannerAgentCard(
            scenarios: scenarios,
            selectedScenarioId: tutorState.selectedScenarioId,
            isPlanning: _isPlanningScenarios,
            isCreatingCustom: _isCreatingCustom,
            customTopicController: _customTopicController,
            onPlanScenarios: _triggerScenarioPlanning,
            onCreateCustomScenario: _createCustomScenario,
            onSelectScenario: _selectScenario,
          ),
          const SizedBox(height: 16),
          const TopicAgentCard(),
        ],
      ),
    );
  }
}
