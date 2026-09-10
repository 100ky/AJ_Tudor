import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../widgets/glass_container.dart';
import '../../services/gemini/translation_service.dart';
import '../../services/gemini/gemini_tts_service.dart';
import '../../services/agents/voice_tutor_agent.dart';

/// Spodní karta pro zobrazení rychlého překladu slova/fráze, poslech výslovnosti
/// a automatické uložení do Smart Flashcards.
class WordTranslationSheet extends ConsumerStatefulWidget {
  final String englishText;
  final String? contextSentence;
  final VoidCallback? onDismissed;

  const WordTranslationSheet({
    super.key,
    required this.englishText,
    this.contextSentence,
    this.onDismissed,
  });

  /// Statická pomocná metoda pro otevření spodní karty
  static Future<void> show(
    BuildContext context, {
    required String englishText,
    String? contextSentence,
    VoidCallback? onDismissed,
    WidgetRef? ref,
  }) async {
    HapticFeedback.selectionClick();

    bool wasVoicePaused = false;

    // Pokud je k dispozici ref a hovor je aktivní, ihned jej pozastavíme
    if (ref != null) {
      final status = ref.read(voiceTutorAgentProvider).status;
      if (status == TutorState.listening ||
          status == TutorState.speaking ||
          status == TutorState.thinking) {
        wasVoicePaused = true;
        ref.read(voiceTutorAgentProvider.notifier).pauseSession();
      }
    }

    if (!context.mounted) return;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (ctx) => WordTranslationSheet(
          englishText: englishText,
          contextSentence: contextSentence,
          onDismissed: onDismissed,
        ),
      );
    } finally {
      onDismissed?.call();

      // Po zavření panelu obnovíme hovor, pokud byl pozastaven tímto panelem
      if (wasVoicePaused && ref != null) {
        final status = ref.read(voiceTutorAgentProvider).status;
        if (status == TutorState.paused) {
          await ref.read(voiceTutorAgentProvider.notifier).resumeSession();
        }
      }
    }
  }

  @override
  ConsumerState<WordTranslationSheet> createState() => _WordTranslationSheetState();
}

class _WordTranslationSheetState extends ConsumerState<WordTranslationSheet> {
  bool _isLoading = true;
  String _translatedText = '';
  String? _errorMessage;
  int? _flashcardId;
  bool _isSaved = false;
  bool _isPlayingTts = false;
  bool _internallyPaused = false;

  @override
  void initState() {
    super.initState();
    _checkAndPauseVoice();
    _performTranslationAndSave();
  }

  void _checkAndPauseVoice() {
    final status = ref.read(voiceTutorAgentProvider).status;
    if (status == TutorState.listening ||
        status == TutorState.speaking ||
        status == TutorState.thinking) {
      _internallyPaused = true;
      ref.read(voiceTutorAgentProvider.notifier).pauseSession();
    }
  }

  @override
  void dispose() {
    if (_internallyPaused) {
      final status = ref.read(voiceTutorAgentProvider).status;
      if (status == TutorState.paused) {
        ref.read(voiceTutorAgentProvider.notifier).resumeSession();
      }
    }
    super.dispose();
  }

  Future<void> _performTranslationAndSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final translationService = ref.read(wordTranslationServiceProvider);

    try {
      final translation = await translationService.translate(
        text: widget.englishText,
        contextSentence: widget.contextSentence,
      );

      if (!mounted) return;

      if (translation.isEmpty || translation == 'Překlad se nezdařil') {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Překlad se nepodařilo načíst.';
        });
        return;
      }

      setState(() {
        _translatedText = translation;
        _isLoading = false;
      });

      // Automaticky uložíme do existujících Flashcards
      final saveResult = await translationService.saveToFlashcards(
        englishText: widget.englishText,
        czechText: translation,
        contextSentence: widget.contextSentence,
      );

      if (!mounted) return;

      if (saveResult.isSuccess) {
        setState(() {
          _flashcardId = saveResult.valueOrNull;
          _isSaved = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Chyba spojení.';
        });
      }
    }
  }

  Future<void> _toggleFlashcard() async {
    final translationService = ref.read(wordTranslationServiceProvider);
    HapticFeedback.mediumImpact();

    if (_isSaved && _flashcardId != null) {
      // Undo – odebrání z kartiček
      final res = await translationService.removeFromFlashcards(_flashcardId!);
      if (mounted && res.isSuccess) {
        setState(() {
          _isSaved = false;
        });
      }
    } else if (!_isSaved && _translatedText.isNotEmpty) {
      // Znovu uložení
      final res = await translationService.saveToFlashcards(
        englishText: widget.englishText,
        czechText: _translatedText,
        contextSentence: widget.contextSentence,
      );
      if (mounted && res.isSuccess) {
        setState(() {
          _flashcardId = res.valueOrNull;
          _isSaved = true;
        });
      }
    }
  }

  Future<void> _playTts() async {
    if (_isPlayingTts) return;
    HapticFeedback.selectionClick();
    setState(() => _isPlayingTts = true);

    try {
      final tts = ref.read(geminiTtsServiceProvider);
      await tts.speak(widget.englishText);
    } finally {
      if (mounted) {
        setState(() => _isPlayingTts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanEn = WordTranslationService.cleanWord(widget.englishText);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          borderRadius: BorderRadius.circular(24),
          color: isDark ? AppTheme.glassDark : AppTheme.glass,
          border: Border.all(
            color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorder,
            width: 1.2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Lišta s úchytem (Drag handle) a zavíracím křížkem ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'PŘEKLAD DO ČEŠTINY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.mutedTextColor(context),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Anglický výraz s tlačítkem výslovnosti ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      cleanEn,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tlačítko přehrání výslovnosti (Gemini TTS)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _playTts,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          _isPlayingTts
                              ? Icons.volume_up_rounded
                              : Icons.volume_mute_rounded,
                          size: 18,
                          color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Český překlad ────────────────────────────────────────────────
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Překládám v kontextu věty...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppTheme.mutedTextColor(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppTheme.error,
                  ),
                )
              else
                Text(
                  _translatedText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.accentLight : AppTheme.accent,
                  ),
                ),

              // ── Kontext věty (pokud existuje) ──────────────────────────────
              if (widget.contextSentence != null &&
                  widget.contextSentence!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    '„${widget.contextSentence!.trim()}“',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.mutedTextColor(context),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // ── Spodní akční řádek se stavem kartiček (Smart Flashcards) ───────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isSaved
                      ? AppTheme.success.withValues(alpha: isDark ? 0.20 : 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSaved
                        ? AppTheme.success.withValues(alpha: 0.4)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSaved
                          ? Icons.check_circle_rounded
                          : Icons.style_outlined,
                      size: 16,
                      color: _isSaved
                          ? (isDark ? const Color(0xFFB4F5BE) : AppTheme.success)
                          : AppTheme.mutedTextColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSaved
                            ? 'Uloženo do Smart Flashcards! 🃏'
                            : 'Není v kartičkách',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _isSaved
                              ? (isDark ? const Color(0xFFB4F5BE) : AppTheme.success)
                              : AppTheme.textColor(context),
                        ),
                      ),
                    ),
                    if (!_isLoading && _translatedText.isNotEmpty)
                      InkWell(
                        onTap: _toggleFlashcard,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            _isSaved ? 'Vrátit ↩' : '+ Uložit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isSaved
                                  ? AppTheme.error
                                  : (isDark
                                      ? AppTheme.primaryLight
                                      : AppTheme.primary),
                            ),
                          ),
                        ),
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
