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
import '../../core/app_theme.dart';

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

  /// Přepne režim chatu na gramatický drill nebo běžný rozhovor.
  void _toggleGrammarDrill(bool value) {
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'AJ Tudor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
            letterSpacing: -0.3,
          ),
        ),
      ),

      body: Column(
        children: [
          // ── Přepínač režimu ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text('Volný rozhovor'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.psychology_alt_outlined, size: 16),
                  label: Text('Gramatický dril'),
                ),
              ],
              selected: {_isGrammarDrill},
              onSelectionChanged: (s) => _toggleGrammarDrill(s.first),
            ),
          ),

          // ── Doporučené scénáře ─────────────────────────────────────────────
          if (!_isGrammarDrill)
            StreamBuilder<List<Scenario>>(
              stream: repo.watchAvailableScenarios(),
              builder: (context, snapshot) {
                final scenarios = snapshot.data ?? [];

                if (scenarios.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(scenarioPlannerAgentProvider).planScenarios(),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Vygenerovat scénáře na míru'),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Doporučené scénáře',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        itemCount: scenarios.length,
                        itemBuilder: (context, index) =>
                            _buildScenarioCard(scenarios[index]),
                      ),
                    ),
                    const Divider(height: 8),
                  ],
                );
              },
            ),

          // ── Seznam zpráv ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),

          // Indikátor načítání
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: AppTheme.outline),
                  ),
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
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Vstupní pole ───────────────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: AppTheme.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onBackground,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Napiš anglicky (nebo česky)...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceMuted,
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
                color: _isLoading
                    ? AppTheme.outline
                    : AppTheme.primary,
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
              child: Icon(
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
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser
                ? AppTheme.primary.withValues(alpha: 0.3)
                : AppTheme.outline,
          ),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.onBackground,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(Scenario s) {
    return GestureDetector(
      onTap: () {
        ref.read(voiceTutorAgentProvider.notifier).selectScenario(s.id, s.tutorInstruction);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scénář „${s.title}" vybrán. Přepni na Voice tab.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 190,
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.onBackground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                _buildDifficultyBadge(s.difficulty),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                s.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppTheme.onSurfaceMuted,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.mic_rounded,
                    size: 12, color: AppTheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Spustit ve Voice',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
