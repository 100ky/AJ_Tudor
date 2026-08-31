import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/chat_message.dart';
import '../../providers/database_provider.dart';
import '../../services/gemini/gemini_tts_service.dart';
import '../app_theme.dart';

/// Chytrá interaktivní bublina zprávy pro chat a hlasové přepisy.
/// 
/// Poskytuje:
/// - Vizuální označení gramatických a lexikálních chyb studenta.
/// - Rozbalovací české vysvětlení pravidla.
/// - Tlačítko pro okamžitý poslech rodilé výslovnosti (Gemini TTS).
/// - Tlačítko pro uložení opravené věty přímo do kartiček (Smart Flashcards).
class SmartChatBubble extends ConsumerStatefulWidget {
  /// Zpráva včetně případných metadat o chybách a opravách.
  final ChatMessage message;

  /// Volitelný callback při klepnutí na celou bublinu.
  final VoidCallback? onTap;

  /// Maximální šířka bubliny v poměru k šířce obrazovky (výchozí: 0.85).
  final double maxWidthFraction;

  const SmartChatBubble({
    super.key,
    required this.message,
    this.onTap,
    this.maxWidthFraction = 0.85,
  });

  @override
  ConsumerState<SmartChatBubble> createState() => _SmartChatBubbleState();
}

class _SmartChatBubbleState extends ConsumerState<SmartChatBubble> {
  bool _isExpanded = false;
  bool _isPlayingTts = false;
  bool _isSavedToFlashcards = false;

  void _copyToClipboard(BuildContext context, String text) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Zpráva zkopírována do schránky',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _playTts(String textToSpeak) async {
    HapticFeedback.selectionClick();
    setState(() => _isPlayingTts = true);

    final tts = ref.read(geminiTtsServiceProvider);
    await tts.speak(textToSpeak);

    if (mounted) {
      setState(() => _isPlayingTts = false);
    }
  }

  Future<void> _saveToFlashcards(ChatMessageCorrection correction) async {
    if (_isSavedToFlashcards) return;

    HapticFeedback.mediumImpact();
    final repo = ref.read(sessionRepositoryProvider);

    final result = await repo.addFlashcard(
      frontText: 'Jak se řekne / oprav: "${correction.userSaid}"?',
      backText: correction.correctForm,
      explanation: correction.explanation,
      errorType: correction.errorType,
      sourceSentence: widget.message.text,
    );

    if (mounted) {
      if (result.isSuccess) {
        setState(() => _isSavedToFlashcards = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.style_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Uloženo do Smart Flashcards! 🃏',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.failureOrNull?.message ?? 'Chyba při ukládání.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * widget.maxWidthFraction;

    final tutorBgColor = AppTheme.glassColor(context);
    final tutorBorderColor = AppTheme.glassBorderColor(context);
    final tutorTextColor = AppTheme.textColor(context);
    final tutorStrongColor =
        isDark ? AppTheme.primaryLight : AppTheme.primaryDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            // Avatar tutora pro zprávy od AI
            if (!isUser) ...[
              Container(
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],

            // Samotné tělo chytré bubliny
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary,
                            AppTheme.primaryDark,
                          ],
                        )
                      : null,
                  color: isUser ? null : tutorBgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  border: Border.all(
                    color: isUser
                        ? AppTheme.primaryLight.withValues(alpha: 0.4)
                        : tutorBorderColor,
                    width: 1.0,
                  ),
                  boxShadow: isUser
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : (isDark
                          ? AppTheme.glassShadowDark
                          : AppTheme.glassShadowLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hlavní text zprávy
                    GestureDetector(
                      onLongPress: () => _copyToClipboard(context, msg.text),
                      onTap: widget.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: isUser
                            ? Text(
                                msg.text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  color: Colors.white,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : MarkdownBody(
                                data: msg.text,
                                selectable: false,
                                styleSheet: MarkdownStyleSheet(
                                  p: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    color: tutorTextColor,
                                    height: 1.45,
                                  ),
                                  strong: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: tutorStrongColor,
                                  ),
                                  em: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: tutorTextColor,
                                  ),
                                  listBullet: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    color: AppTheme.primary,
                                  ),
                                  code: GoogleFonts.firaCode(
                                    fontSize: 13,
                                    color: tutorStrongColor,
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: isDark ? 0.2 : 0.08),
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // ── SMART KARTA OPRAV (pouze pokud zpráva obsahuje chyby) ──────────
                    if (isUser && msg.hasCorrections) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var correction in msg.corrections!) ...[
                              // Hlavička s porovnáním: [Chyba ❌ -> Správně ✅]
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      correction.userSaid,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFFB4AB),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        correction.correctForm,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFB4F5BE),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Vysvětlení (kliknutím na nápis nebo ikonu)
                              InkWell(
                                onTap: () => setState(() => _isExpanded = !_isExpanded),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline_rounded,
                                        size: 14,
                                        color: Colors.amber.shade200,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _isExpanded
                                              ? correction.explanation
                                              : 'Proč? Zobrazit pravidlo...',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.9),
                                            height: 1.35,
                                            fontStyle: _isExpanded
                                                ? FontStyle.normal
                                                : FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Akční tlačítka: [🔊 Poslech] a [➕ Do kartiček]
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Tlačítko přehrání výslovnosti přes Gemini TTS
                                  InkWell(
                                    onTap: _isPlayingTts
                                        ? null
                                        : () => _playTts(msg.correctedSentence ??
                                            correction.correctForm),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isPlayingTts
                                                ? Icons.volume_up_rounded
                                                : Icons.volume_mute_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Výslovnost',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Tlačítko přidání do Smart Flashcards
                                  InkWell(
                                    onTap: _isSavedToFlashcards
                                        ? null
                                        : () => _saveToFlashcards(correction),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isSavedToFlashcards
                                            ? AppTheme.success.withValues(alpha: 0.3)
                                            : Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isSavedToFlashcards
                                                ? Icons.check_rounded
                                                : Icons.add_circle_outline_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isSavedToFlashcards
                                                ? 'V kartičkách'
                                                : 'Do kartiček',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Tlačítko poslechu pro zprávy tutora
                    if (!isUser) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlayingTts
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_mute_rounded,
                                size: 16,
                                color: tutorStrongColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Přehrát zprávu',
                              onPressed: _isPlayingTts
                                  ? null
                                  : () => _playTts(msg.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
