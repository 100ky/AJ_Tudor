import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/session_repository.dart';

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
    setState(() {
      _isPlanningScenarios = true;
    });

    try {
      await ref.read(scenarioPlannerAgentProvider).planScenarios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plánovač témat úspěšně vygeneroval 3 nové scénáře! 🎯'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při plánování scénářů: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlanningScenarios = false;
        });
      }
    }
  }

  Future<void> _createCustomScenario() async {
    final text = _customTopicController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isCreatingCustom = true;
    });

    try {
      await ref.read(scenarioPlannerAgentProvider).planCustomScenario(text);
      if (mounted) {
        _customTopicController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vlastní scénář "$text" úspěšně vytvořen! 🎯'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při vytváření scénáře: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingCustom = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final repo = ref.watch(sessionRepositoryProvider);
    final userProfileStream = repo.watchUserProfile();
    final sessionsStream = repo.watchAllSessions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moji AI Agenti'),
        centerTitle: true,
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userProfileStream,
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;

          return StreamBuilder<List<Session>>(
            stream: sessionsStream,
            builder: (context, sessionsSnapshot) {
              final sessions = sessionsSnapshot.data ?? [];
              final lastSession = sessions.isNotEmpty ? sessions.first : null;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  
                  // AGENT 1: Konverzační Tutor
                  _buildTutorAgentCard(tutorState),
                  const SizedBox(height: 20),

                  // AGENT 2: Analytik skóre
                  _buildAnalyzerAgentCard(profile, lastSession, tutorState.status),
                  const SizedBox(height: 20),

                  // AGENT 3: Plánovač témat
                  _buildPlannerAgentCard(repo, tutorState.selectedScenarioId),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withValues(alpha: 0.15), Colors.deepPurpleAccent.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.diversity_3, size: 40, color: Colors.blueAccent),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-agentní systém AJ Tudor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Tři specializovaní AI agenti spolupracují na tvé výuce angličtiny pro maximální efektivitu.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTutorAgentCard(VoiceTutorState tutorState) {
    final status = tutorState.status;
    final isActive = status != TutorState.idle && status != TutorState.error;
    
    Color statusColor;
    String statusText;
    switch (status) {
      case TutorState.listening:
        statusColor = Colors.greenAccent;
        statusText = 'Poslouchá tě...';
        break;
      case TutorState.speaking:
        statusColor = Colors.purpleAccent;
        statusText = 'Právě mluví...';
        break;
      case TutorState.thinking:
        statusColor = Colors.blueAccent;
        statusText = 'Přemýšlí...';
        break;
      case TutorState.connecting:
      case TutorState.reconnecting:
        statusColor = Colors.orangeAccent;
        statusText = 'Připojuje se...';
        break;
      case TutorState.error:
        statusColor = Colors.redAccent;
        statusText = 'Chyba spojení';
        break;
      case TutorState.paused:
        statusColor = Colors.amberAccent;
        statusText = 'Pozastaveno';
        break;
      case TutorState.idle:
        statusColor = Colors.grey;
        statusText = 'Připraven / Neaktivní';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Konverzační Tutor',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Agent zodpovědný za přátelskou diskuzi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        _buildPulseIndicator(statusColor),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Osobnost a styl:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '• AJ Tudor je rodilý mluvčí z Londýna, který momentálně žije v Praze.\n'
              '• NEBUDE tě jen vyslýchat! Rád reaguje, sdílí vlastní historky o vaření, procházkách v parku nebo o tom, jak si zvyká na české pivo.\n'
              '• Mluví pomalu a přizpůsobuje slova tvé úrovni angličtiny.',
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzerAgentCard(UserProfile? profile, Session? lastSession, TutorState tutorStatus) {
    final isAnalyzing = tutorStatus == TutorState.connecting || tutorStatus == TutorState.thinking;
    final fluencyScore = lastSession?.fluencyScore;
    final fluencyPercent = fluencyScore != null ? (fluencyScore * 100).toInt() : null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.tealAccent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Analytik skóre',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Agent pro sémantickou analýzu pokroku',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAnalyzing ? Colors.amber : Colors.tealAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isAnalyzing ? Colors.amber : Colors.tealAccent).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    isAnalyzing ? 'ČEKÁ NA KONEC RELACE' : 'AKTIVNÍ / PŘIPRAVEN',
                    style: TextStyle(
                      color: isAnalyzing ? Colors.amber : Colors.tealAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Poslední sémantická analýza:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'Plynulost',
                    value: fluencyPercent != null ? '$fluencyPercent%' : 'N/A',
                    color: Colors.blueAccent,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'Zjištěná Úroveň',
                    value: profile?.targetLevel ?? 'B1',
                    color: Colors.tealAccent,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'Celkem chyb',
                    value: lastSession?.totalErrors != null ? '${lastSession!.totalErrors}' : '0',
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (profile?.memoryBriefing != null && profile!.memoryBriefing!.isNotEmpty) ...[
              const Text(
                'Pedagogický zápis v paměti:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.1)),
                ),
                child: Text(
                  profile.memoryBriefing!,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlannerAgentCard(SessionRepository repo, int? selectedScenarioId) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. Plánovač témat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Agent vytvářející scénáře na základě chyb',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_isPlanningScenarios ? Colors.deepOrangeAccent : Colors.orangeAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (_isPlanningScenarios ? Colors.deepOrangeAccent : Colors.orangeAccent).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _isPlanningScenarios ? 'PLÁNUJE...' : 'PŘIPRAVEN',
                    style: TextStyle(
                      color: _isPlanningScenarios ? Colors.deepOrangeAccent : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Aktuální scénáře na míru:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Scenario>>(
              stream: repo.watchAvailableScenarios(),
              builder: (context, snapshot) {
                final scenarios = snapshot.data ?? [];
                
                if (scenarios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Zatím nejsou naplánovány žádné scénáře. Klikni na tlačítko níže pro vygenerování.',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: scenarios.map((s) => _buildMiniScenarioTile(s, selectedScenarioId)).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isPlanningScenarios ? null : _triggerScenarioPlanning,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isPlanningScenarios
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isPlanningScenarios ? 'Plánování nových témat...' : 'Vymyslet nová témata'),
              ),
            ),
            const SizedBox(height: 16),
            // TEXTOVÝ INPUT PRO VLASTNÍ TÉMA
            const Divider(height: 24),
            const Text(
              'Nebo napiš své vlastní téma:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTopicController,
                    decoration: InputDecoration(
                      hintText: 'Napiš stručně téma (např. "objednávka jídla v restauraci")...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _isCreatingCustom
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _createCustomScenario(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isCreatingCustom ? null : _createCustomScenario,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({required String label, required String value, required Color color}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScenarioTile(Scenario scenario, int? selectedId) {
    final isSelected = selectedId == scenario.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? Colors.orangeAccent : Colors.grey[800]!,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          ref.read(voiceTutorAgentProvider.notifier).selectScenario(scenario.id, scenario.tutorInstruction);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scénář "${scenario.title}" vybrán! Můžeš spustit Chat nebo Voice. 🗣️'),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.label_important_outline,
                color: Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      scenario.description,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSelected ? 'AKTIVNÍ' : scenario.difficulty.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.orangeAccent,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseIndicator(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 4,
            spreadRadius: 2,
          )
        ],
      ),
    );
  }
}
