import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/prompt/system_prompt_builder.dart';
import '../../data/database/app_database.dart';
import '../../data/models/chat_message.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/smart_chat_bubble.dart';


/// Obrazovka pro textovou konverzaci s AI a výběr scénářů.
///
/// Umožňuje uživateli psát si s Gemini (Batch režim) a vybírat si
/// personalizované scénáře pro následný hlasový trénink.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isGrammarDrill = false;
  bool _showScenarios = true;
  Scenario? _selectedScenario;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Vybere scénář, sbalí výběr animací a případně zahájí konverzaci.
  void _selectScenario(Scenario s) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedScenario = s;
      _showScenarios = false;
    });

    ref.read(voiceTutorAgentProvider.notifier).selectScenario(s.id, s.tutorInstruction);

    // Pokud je chat prázdný, tutor automaticky zahájí konverzaci k tomuto tématu
    if (_messages.isEmpty) {
      _startScenarioConversation(s);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Téma „${s.title}" vybráno! 💬'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Změnit',
            onPressed: () {
              setState(() {
                _showScenarios = true;
              });
            },
          ),
        ),
      );
    }
  }

  /// Automatické zahájení konverzace na zvolené téma s tutorem.
  Future<void> _startScenarioConversation(Scenario s) async {
    final client = ref.read(geminiBatchClientProvider);
    if (client == null) return;

    setState(() {
      _isLoading = true;
    });

    final profile = ref.read(userProfileProvider).value;
    final prompt =
        'Let\'s start the conversation for the scenario "${s.title}". Scenario description: ${s.description}. Tutor instruction: ${s.tutorInstruction}. Please start by greeting me warmly and opening the conversation in English at level ${profile?.targetLevel ?? "B1"}.';

    final response = await client.sendMessage(
      prompt,
      systemPrompt: SystemPromptBuilder.buildTutorPrompt(
        targetLevel: profile?.targetLevel ?? 'B1',
        scenarioContext: s.tutorInstruction,
      ),
    );

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Přepne režim chatu na gramatický drill nebo běžný rozhovor.
  void _toggleGrammarDrill(bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      _isGrammarDrill = value;
      _messages.clear();
      if (_isGrammarDrill) {
        _messages.add(ChatMessage(
          'Ahoj! Vítej v gramatickém drilu. Podívám se na tvé minulé chyby a připravím pro tebe překladová cvičení. Napiš cokoliv (např. „start") pro spuštění!',
          isUser: false,
        ));
      }
    });
  }

  /// Odešle textovou zprávu do Gemini a přidá odpověď do seznamu.
  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final client = ref.read(geminiBatchClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chybí API klíč! Nastavte ho v Settings.')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    String? systemPrompt;
    if (_isGrammarDrill) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        systemPrompt = SystemPromptBuilder.buildGrammarDrillPrompt(
          recurringErrors: profile.recurringErrors,
          targetLevel: profile.targetLevel,
          vocabulary: profile.vocabulary,
        );
      }
    }

    final response = await client.sendMessage(text, systemPrompt: systemPrompt);

    setState(() {
      _messages.add(ChatMessage(response, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);

    ref.listen(modelProvider, (previous, next) {
      if (previous != next) {
        setState(() => _messages.clear());
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'AJ Tudor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
            letterSpacing: -0.3,
          ),
        ),
      ),

      body: Column(
        children: [
          // ── Přepínač režimu ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: Text(
                    'Volný rozhovor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.psychology_alt_outlined, size: 15),
                  label: Text(
                    'Gramatický dril',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              selected: {_isGrammarDrill},
              onSelectionChanged: (s) => _toggleGrammarDrill(s.first),
            ),
          ),

          // ── Scrollable obsah (Scénáře + Zprávy + Loader) ──────────────────
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                // ── Doporučené scénáře ─────────────────────────────────────
                if (!_isGrammarDrill)
                  StreamBuilder<List<Scenario>>(
                    stream: repo.watchAvailableScenarios(),
                    builder: (context, snapshot) {
                      final scenarios = snapshot.data ?? [];

                      if (scenarios.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => ref
                                .read(scenarioPlannerAgentProvider)
                                .planScenarios(),
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 16),
                            label:
                                const Text('Vygenerovat scénáře na míru'),
                          ),
                        );
                      }

                      return AnimatedSize(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: _showScenarios
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome_rounded,
                                            size: 15,
                                            color: AppTheme.accent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'DOPORUČENÁ TÉMATA K PROCVIČENÍ',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.mutedTextColor(
                                                context),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_selectedScenario != null ||
                                            _messages.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback
                                                  .selectionClick();
                                              setState(() =>
                                                  _showScenarios = false);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'Skrýt',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppTheme.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  const Icon(
                                                      Icons
                                                          .keyboard_arrow_up_rounded,
                                                      size: 16,
                                                      color:
                                                          AppTheme.primary),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ...scenarios
                                      .map((s) => _buildScenarioCard(s)),
                                  const SizedBox(height: 8),
                                  Divider(
                                      color: AppTheme.outlineLightColor(
                                          context)),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassContainer(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  borderRadius: BorderRadius.circular(16),
                                  shadows: AppTheme.glassShadowLight,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accent
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                            Icons.theater_comedy_rounded,
                                            size: 16,
                                            color: AppTheme.accent),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedScenario != null
                                              ? 'Téma: ${_selectedScenario!.title}'
                                              : 'Scénář na míru vybrán',
                                          style: GoogleFonts
                                              .plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textColor(
                                                context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          setState(
                                              () => _showScenarios = true);
                                        },
                                        style: TextButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 14),
                                        label: Text(
                                          'Změnit',
                                          style: GoogleFonts
                                              .plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      );
                    },
                  ),

                // ── Seznam zpráv ───────────────────────────────────────────
                ..._messages.map((msg) => _buildChatBubble(msg)),

                // ── Indikátor načítání ─────────────────────────────────────
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        shadows: AppTheme.glassShadowLight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Tutor přemýšlí...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppTheme.mutedTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Vstupní pole ─────────────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.backgroundDark : AppTheme.background)
            .withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: (isDark ? AppTheme.outlineDark : AppTheme.outline)
                .withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? AppTheme.onBackgroundDark : AppTheme.onBackground,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Napiš anglicky (nebo česky)...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppTheme.onSurfaceMutedDark
                      : AppTheme.onSurfaceMuted,
                  fontSize: 15,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                      ),
                color: _isLoading ? AppTheme.outline : null,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final useSmartBubbles = ref.watch(smartBubblesEnabledProvider);
    if (useSmartBubbles) {
      return SmartChatBubble(
        message: msg,
      );
    }
    return ChatBubble(
      text: msg.text,
      isUser: msg.isUser,
    );
  }

  Widget _buildScenarioCard(Scenario s) {
    final isSelected = _selectedScenario?.id == s.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectScenario(s),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? AppTheme.accent.withValues(alpha: isDark ? 0.20 : 0.08)
              : null,
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.45)
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [AppTheme.accent, AppTheme.accentLight]
                            : [
                                AppTheme.primary.withValues(alpha: 0.2),
                                AppTheme.primaryLight.withValues(alpha: 0.1),
                              ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.theater_comedy_rounded,
                      size: 18,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDifficultyBadge(s.difficulty),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.surfaceTextColor(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 13, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Vybrat téma a zahájit konverzaci',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppTheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
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
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
