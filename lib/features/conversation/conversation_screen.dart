import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/config/config_providers.dart';
import '../../core/widgets/grouped_section.dart';
import '../../data/data_providers.dart';
import '../../data/models/chat_message.dart';
import 'grammar_drill_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/drill/drill_empty_state.dart';
import 'widgets/drill/drill_input_bar.dart';
import 'widgets/smart_chat_bubble.dart';

/// Obrazovka pro interaktivní gramatický dril a textové cvičení s AI.
///
/// Zaměřuje se na překladová cvičení z češtiny do angličtiny
/// a odstraňování konkrétních opakujících se chyb studenta.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  GrammarDrillController get _drill => ref.read(grammarDrillControllerProvider.notifier);

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

  bool _ensureApiKey() {
    if (_drill.hasApiKey) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chybí API klíč! Nastavte ho v Settings.')),
    );
    return false;
  }

  /// Spustí nový gramatický dril – AI vybere chybu, vysvětlí pravidlo a zadá věty k překladu.
  void _startDrill([String? topicHint]) {
    if (!_ensureApiKey()) return;
    HapticFeedback.mediumImpact();
    _drill.startDrill(topicHint);
  }

  /// Odešle zprávu / řešení překladu tutorovi.
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!_ensureApiKey()) return;

    HapticFeedback.lightImpact();
    _textController.clear();
    _drill.send(text);
  }

  /// Resetuje konverzaci drilu.
  void _resetDrill() {
    HapticFeedback.selectionClick();
    _drill.reset();
  }

  @override
  Widget build(BuildContext context) {
    final drill = ref.watch(grammarDrillControllerProvider);
    final profile = ref.watch(userProfileProvider).value;
    final level = profile?.targetLevel ?? 'B1';

    // Posun na konec po každé nové zprávě
    ref.listen(grammarDrillControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenTitle(
              'Gramatický dril',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      level,
                      style: AppTheme.font(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (drill.messages.isNotEmpty)
                    IconButton(
                      onPressed: _resetDrill,
                      tooltip: 'Restartovat dril',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Scrollable obsah (Prázdný stav nebo Zprávy + Loader) ───────────
            Expanded(
              child: (drill.messages.isEmpty && !drill.isLoading)
                  ? DrillEmptyState(
                      errors: drillFocusErrors(profile?.recurringErrors),
                      level: level,
                      isLoading: drill.isLoading,
                      onStart: () => _startDrill(),
                      onStartTopic: _startDrill,
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      children: [
                        ...drill.messages.map(_buildChatBubble),
                        if (drill.isLoading) const DrillThinkingBubble(),
                      ],
                    ),
            ),

            // ── Vstupní pole ─────────────────────────────────────────────────
            DrillInputBar(
              controller: _textController,
              isLoading: drill.isLoading,
              onSend: _sendMessage,
            ),
          ],
        ),
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
}
