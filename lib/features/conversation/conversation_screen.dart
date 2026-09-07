import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/chat_bubble.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/smart_chat_bubble.dart';
import '../../data/models/chat_message.dart';
import '../../providers/config_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/prompt/system_prompt_builder.dart';

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
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

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

  /// Spustí nový gramatický dril – AI vybere chybu, vysvětlí pravidlo a zadá věty k překladu.
  Future<void> _startDrill([String? topicHint]) async {
    final client = ref.read(geminiBatchClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chybí API klíč! Nastavte ho v Settings.')),
      );
      return;
    }

    final userDisplayText = (topicHint != null && topicHint.isNotEmpty)
        ? 'Procvičit téma: $topicHint'
        : 'Spustit gramatický dril na mé chyby';

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _messages.clear();
      _messages.add(ChatMessage(userDisplayText, isUser: true));
    });
    _scrollToBottom();

    final profile = ref.read(userProfileProvider).value;
    final systemPrompt = SystemPromptBuilder.buildGrammarDrillPrompt(
      recurringErrors: profile?.recurringErrors ?? '',
      targetLevel: profile?.targetLevel ?? 'B1',
      vocabulary: profile?.vocabulary,
    );

    final kickoffMessage = (topicHint != null && topicHint.isNotEmpty)
        ? 'Ahoj Tutore! Chci si procvičit téma: "$topicHint". Krátce mi česky vysvětli pravidlo a dej mi 3 české věty k přeložení do angličtiny.'
        : 'Ahoj Tutore! Začni prosím nový gramatický dril na mé opakující se chyby. Vyber jednu z mých slabin, stručně mi česky vysvětli pravidlo a dej mi 3 české věty k přeložení do angličtiny.';

    try {
      final response =
          await client.sendMessage(kickoffMessage, systemPrompt: systemPrompt);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(response, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            '❌ Nepodařilo se spustit dril: $e\nZkontrolujte připojení nebo zkuste jiné téma.',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
  }

  /// Odešle zprávu / řešení překladu do Gemini a přidá odpověď.
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

    final profile = ref.read(userProfileProvider).value;
    final systemPrompt = SystemPromptBuilder.buildGrammarDrillPrompt(
      recurringErrors: profile?.recurringErrors ?? '',
      targetLevel: profile?.targetLevel ?? 'B1',
      vocabulary: profile?.vocabulary,
    );

    try {
      final response = await client.sendMessage(text, systemPrompt: systemPrompt);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(response, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage('Chyba při komunikaci: $e', isUser: false));
          _isLoading = false;
        });
      }
    }
  }

  /// Resetuje konverzaci drilu.
  void _resetDrill() {
    HapticFeedback.selectionClick();
    setState(() {
      _messages.clear();
    });
  }

  List<String> _extractErrors(String? errorsJson) {
    if (errorsJson == null || errorsJson.isEmpty || errorsJson == '[]') return [];
    try {
      if (errorsJson.startsWith('[')) {
        final list = jsonDecode(errorsJson);
        if (list is List) {
          return list.map((e) => e.toString()).take(4).toList();
        }
      }
    } catch (_) {}
    return errorsJson
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final level = profile?.targetLevel ?? 'B1';
    final errors = _extractErrors(profile?.recurringErrors);

    ref.listen(modelProvider, (previous, next) {
      if (previous != next) {
        setState(() => _messages.clear());
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Text(
              'Gramatický dril',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                level,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _resetDrill,
              tooltip: 'Restartovat dril',
              icon: Icon(
                Icons.refresh_rounded,
                color: AppTheme.mutedTextColor(context),
                size: 20,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Scrollable obsah (Prázdný stav nebo Zprávy + Loader) ───────────
          Expanded(
            child: (_messages.isEmpty && !_isLoading)
                ? _buildDrillEmptyState(errors, level)
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      ..._messages.map((msg) => _buildChatBubble(msg)),
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
                                    'Tutor vyhodnocuje a připravuje cvičení...',
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

  // ── Prázdný stav s přehledem chyb a rychlým spuštěním ──────────────────────
  Widget _buildDrillEmptyState(List<String> errors, String level) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                Icons.psychology_alt_rounded,
                size: 32,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gramatická cvičebna',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tutor ti zadá 3 krátké české věty k překladu zaměřené na tvé chyby, ihned je zkontroluje a vysvětlí gramatická pravidla.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Karta zaměření drilu
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(18),
              color: AppTheme.primary.withValues(alpha: 0.05),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.track_changes_rounded,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'ZAMĚŘENÍ PRO ÚROVEŇ $level',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (errors.isNotEmpty) ...[
                    Text(
                      'Tvé zaznamenané opakující se chyby:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: errors.map((e) {
                        String clean = e;
                        if (clean.length > 50) {
                          clean = '${clean.substring(0, 48)}...';
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            clean,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Text(
                      'Zatím nemáš nasbírané chyby z hlasových lekcí. Tutor pro tebe vybere typické gramatické jevy pro úroveň $level.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppTheme.surfaceTextColor(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Hlavní tlačítko pro spuštění drilu
            GestureDetector(
              onTap: _isLoading ? null : () => _startDrill(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Připravuji dril...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Spustit gramatický dril',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Rychlé chipsy pro konkrétní témata
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickDrillChip('Předpřítomný čas (Present Perfect)'),
                _buildQuickDrillChip('Podmínkové věty (Conditionals)'),
                _buildQuickDrillChip('Předložky času a místa (in, at, on)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDrillChip(String topic) {
    return ActionChip(
      onPressed: _isLoading ? null : () => _startDrill(topic),
      avatar: Icon(Icons.bolt_rounded, size: 14, color: AppTheme.primary),
      label: Text(
        topic,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE6100C22) : const Color(0xE6FFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textColor(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Napiš překlad nebo se zeptej na gramatiku...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context),
                  fontSize: 14,
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
}
