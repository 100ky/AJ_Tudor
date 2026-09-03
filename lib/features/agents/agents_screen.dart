import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/database_provider.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/agents/topic_preparation_agent.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/session_repository.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';

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

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    final repo = ref.watch(sessionRepositoryProvider);
    final userProfileStream = repo.watchUserProfile();
    final sessionsStream = repo.watchAllSessions();

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
      body: StreamBuilder<UserProfile?>(
        stream: userProfileStream,
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;

          return StreamBuilder<List<Session>>(
            stream: sessionsStream,
            builder: (context, sessionsSnapshot) {
              final sessions = sessionsSnapshot.data ?? [];
              final lastSession =
                  sessions.isNotEmpty ? sessions.first : null;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 20),
                  _buildTutorAgentCard(context, tutorState),
                  const SizedBox(height: 16),
                  _buildAnalyzerAgentCard(
                      context, profile, lastSession, tutorState.status),
                  const SizedBox(height: 16),
                  _buildPlannerAgentCard(
                      context, repo, tutorState.selectedScenarioId),
                  const SizedBox(height: 16),
                  _buildTopicAgentCard(context),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.speaking.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.diversity_3, size: 28, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-agentní systém AJ Tudor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tři specializovaní AI agenti spolupracují na tvé výuce angličtiny.',
                  style: GoogleFonts.plusJakartaSans(
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

  Widget _buildTutorAgentCard(BuildContext context, VoiceTutorState tutorState) {
    final status = tutorState.status;
    final isActive =
        status != TutorState.idle && status != TutorState.error;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.record_voice_over,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Konverzační Tutor',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context)),
                    ),
                    Text(
                      'Agent zodpovědný za přátelskou diskuzi',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.mutedTextColor(context)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(statusText, statusColor, isActive),
            ],
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

  Widget _buildAnalyzerAgentCard(BuildContext context,
      UserProfile? profile, Session? lastSession, TutorState tutorStatus) {
    final isAnalyzing = tutorStatus == TutorState.connecting ||
        tutorStatus == TutorState.thinking;
    final fluencyScore = lastSession?.fluencyScore;
    final fluencyPercent =
        fluencyScore != null ? (fluencyScore * 100).toInt() : null;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics,
                    color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Analytik skóre',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context)),
                    ),
                    Text(
                      'Agent pro sémantickou analýzu pokroku',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.mutedTextColor(context)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(
                isAnalyzing ? 'ČEKÁ NA KONEC RELACE' : 'AKTIVNÍ',
                isAnalyzing ? AppTheme.warning : AppTheme.success,
                false,
              ),
            ],
          ),
          Divider(color: AppTheme.outlineLightColor(context), height: 24),
          Text(
            'Poslední sémantická analýza:',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildMetricItem(
                      context: context,
                      label: 'Plynulost',
                      value:
                          fluencyPercent != null ? '$fluencyPercent%' : 'N/A',
                      color: AppTheme.primary)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMetricItem(
                      context: context,
                      label: 'Zjištěná Úroveň',
                      value: profile?.targetLevel ?? 'B1',
                      color: AppTheme.success)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMetricItem(
                      context: context,
                      label: 'Celkem chyb',
                      value: lastSession?.totalErrors != null
                          ? '${lastSession!.totalErrors}'
                          : '0',
                      color: AppTheme.error)),
            ],
          ),
          if (profile?.memoryBriefing != null &&
              profile!.memoryBriefing!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Pedagogický zápis v paměti:',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.mutedTextColor(context)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.15)),
              ),
              child: Text(
                profile.memoryBriefing!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: AppTheme.surfaceTextColor(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannerAgentCard(BuildContext context,
      SessionRepository repo, int? selectedScenarioId) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome,
                    color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Plánovač témat',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context)),
                    ),
                    Text(
                      'Agent vytvářející scénáře na základě chyb',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.mutedTextColor(context)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(
                _isPlanningScenarios ? 'PLÁNUJE...' : 'PŘIPRAVEN',
                _isPlanningScenarios
                    ? AppTheme.warning
                    : AppTheme.accent,
                false,
              ),
            ],
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
          StreamBuilder<List<Scenario>>(
            stream: repo.watchAvailableScenarios(),
            builder: (context, snapshot) {
              final scenarios = snapshot.data ?? [];

              if (scenarios.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Zatím nejsou naplánovány žádné scénáře. Klikni na tlačítko níže.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.mutedTextColor(context)),
                  ),
                );
              }

              return Column(
                children: scenarios
                    .map((s) =>
                        _buildMiniScenarioTile(context, s, selectedScenarioId))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _isPlanningScenarios ? null : _triggerScenarioPlanning,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isPlanningScenarios
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isPlanningScenarios
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
                  controller: _customTopicController,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textColor(context), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Napiš téma (např. „objednávka v restauraci")...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.mutedTextColor(context), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon: _isCreatingCustom
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _createCustomScenario(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isCreatingCustom ? null : _createCustomScenario,
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
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopicAgentCard(BuildContext context) {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final isDark = AppTheme.isDark(context);
    final topic = topicState.topic;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Startup Topic Agent',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    Text(
                      'Příprava témat z historie & paměti „O mně"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(
                topicState.isLoading ? 'Generuji...' : 'Připraven',
                topicState.isLoading ? AppTheme.accent : AppTheme.success,
                topicState.isLoading,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tento agent se probouzí po startu aplikace a po ukončení každého rozhovoru. '
            'Analyzuje transkripty z minulých lekcí a informace, které o vás Tudor ví, '
            'aby navrhl neotřelé konverzační téma a zabránil opakování dotazů (např. na mazlíčky a záliby).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.surfaceTextColor(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (topic != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_rounded,
                          size: 16, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        'AKTUÁLNĚ PŘIPRAVENÉ TÉMA:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topic.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '„${topic.openerEn}“',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: topicState.isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(topicPreparationAgentProvider.notifier)
                          .prepareTopic(force: true);
                    },
              icon: topicState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(topicState.isLoading
                  ? 'Připravuji nové téma...'
                  : 'Přeplánovat téma nyní'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String text, Color color, bool showPulse) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, color: AppTheme.mutedTextColor(context)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScenarioTile(
      BuildContext context, Scenario scenario, int? selectedId) {
    final isSelected = selectedId == scenario.id;
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
        onTap: () {
          ref
              .read(voiceTutorAgentProvider.notifier)
              .selectScenario(scenario.id, scenario.tutorInstruction);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Scénář „${scenario.title}" vybrán! Můžeš spustit Voice. 🗣️')),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          fontSize: 11,
                          color: AppTheme.mutedTextColor(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : (isDark
                          ? AppTheme.backgroundSecondaryDark
                          : AppTheme.backgroundSecondary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSelected
                      ? 'AKTIVNÍ'
                      : scenario.difficulty.toUpperCase(),
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
