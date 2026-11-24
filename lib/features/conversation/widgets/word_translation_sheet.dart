import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/gemini/translation_service.dart';
import '../../../services/gemini/gemini_tts_service.dart';
import '../../../services/agents/voice_tutor_agent.dart';

/// Spodní karta pro zobrazení rychlého překladu slova/fráze, poslech výslovnosti
/// a uložení do Smart Flashcards tlačítkem „+ Uložit“.
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
  late String _currentEnglishText;
  late final String _originalSentence;

  bool get _isSentence {
    final words = _currentEnglishText.trim().split(RegExp(r'\s+'));
    return words.length > 3;
  }

  String get _effectiveContextSentence {
    if (widget.contextSentence != null && widget.contextSentence!.trim().isNotEmpty) {
      return widget.contextSentence!;
    }
    return _originalSentence;
  }

  List<String> get _sentenceWords {
    return _currentEnglishText
        .split(RegExp(r'\s+'))
        .map((w) => WordTranslationService.cleanWord(w))
        .where((w) => w.length > 1 || w.toLowerCase() == 'a' || w.toLowerCase() == 'i')
        .toSet()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _currentEnglishText = widget.englishText;
    _originalSentence = widget.contextSentence ?? widget.englishText;
    _checkAndPauseVoice();
    _translate();
  }

  VoiceTutorAgent? _voiceTutorAgent;

  void _checkAndPauseVoice() {
    _voiceTutorAgent = ref.read(voiceTutorAgentProvider.notifier);
    final status = _voiceTutorAgent?.currentStatus;
    if (status == TutorState.listening ||
        status == TutorState.speaking ||
        status == TutorState.thinking) {
      _internallyPaused = true;
      _voiceTutorAgent?.pauseSession();
    }
  }

  @override
  void dispose() {
    if (_internallyPaused && _voiceTutorAgent != null) {
      if (_voiceTutorAgent!.currentStatus == TutorState.paused) {
        _voiceTutorAgent!.resumeSession();
      }
    }
    super.dispose();
  }

  bool get _canExpandLeft {
    final sentence = _effectiveContextSentence.toLowerCase();
    final current = _currentEnglishText.trim().toLowerCase();
    final idx = sentence.indexOf(current);
    return idx > 0 && sentence.substring(0, idx).trim().isNotEmpty;
  }

  bool get _canExpandRight {
    final sentence = _effectiveContextSentence.toLowerCase();
    final current = _currentEnglishText.trim().toLowerCase();
    final idx = sentence.indexOf(current);
    if (idx < 0) return false;
    return (idx + current.length) < sentence.length &&
        sentence.substring(idx + current.length).trim().isNotEmpty;
  }

  void _expandLeft() async {
    if (!_canExpandLeft) return;
    final sentence = _effectiveContextSentence;
    final lowerSentence = sentence.toLowerCase();
    final lowerCurrent = _currentEnglishText.trim().toLowerCase();
    final idx = lowerSentence.indexOf(lowerCurrent);
    if (idx <= 0) return;

    final prefix = sentence.substring(0, idx).trimRight();
    final prefixWords = prefix.split(RegExp(r'\s+'));
    if (prefixWords.isEmpty) return;

    final addedWord = prefixWords.last;
    final startIdx = prefix.lastIndexOf(addedWord);
    final newText = sentence.substring(startIdx, idx + _currentEnglishText.trim().length).trim();

    await _updatePhrase(newText);
  }

  void _expandRight() async {
    if (!_canExpandRight) return;
    final sentence = _effectiveContextSentence;
    final lowerSentence = sentence.toLowerCase();
    final lowerCurrent = _currentEnglishText.trim().toLowerCase();
    final idx = lowerSentence.indexOf(lowerCurrent);
    if (idx < 0) return;

    final endIdx = idx + _currentEnglishText.trim().length;
    if (endIdx >= sentence.length) return;

    final suffix = sentence.substring(endIdx).trimLeft();
    final suffixWords = suffix.split(RegExp(r'\s+'));
    if (suffixWords.isEmpty) return;

    final addedWord = suffixWords.first;
    final addedWordEnd = sentence.indexOf(addedWord, endIdx) + addedWord.length;
    final newText = sentence.substring(idx, addedWordEnd).trim();

    await _updatePhrase(newText);
  }

  /// Přepne překládanou frázi. S [save] (výběr slovíčka z věty „pro kartičku“) ji rovnou uloží
  /// do kartiček. Kartička uložená k předchozí frázi se přesune na novou.
  Future<void> _updatePhrase(String newPhrase, {bool save = false}) async {
    final clean = WordTranslationService.cleanWord(newPhrase);
    if (clean.isEmpty || clean.toLowerCase() == _currentEnglishText.toLowerCase()) return;

    HapticFeedback.selectionClick();

    final hadCard = _isSaved && _flashcardId != null;
    if (hadCard) {
      final translationService = ref.read(wordTranslationServiceProvider);
      try {
        await translationService.removeFromFlashcards(_flashcardId!);
      } catch (_) {}
      _isSaved = false;
      _flashcardId = null;
    }

    setState(() {
      _currentEnglishText = clean;
    });

    await _translate(saveToFlashcards: save || hadCard);
  }

  /// Přeloží aktuální frázi. Do kartiček ji uloží jen se [saveToFlashcards] –
  /// jinak až tlačítkem „+ Uložit“, aby z náhodného označení nevznikaly kartičky.
  Future<void> _translate({bool saveToFlashcards = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final translationService = ref.read(wordTranslationServiceProvider);

    try {
      final translation = await translationService.translate(
        text: _currentEnglishText,
        contextSentence: _effectiveContextSentence,
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

      // ZÁSADA ATOMICKÝCH KARTIČEK:
      // Celou větu (> 3 slova) do kartiček sami neukládáme. Přeložíme ji pro porozumění
      // a níže nabídneme výběr konkrétního slovíčka s kontextem této věty.
      if (saveToFlashcards && !_isSentence) {
        final saveResult = await translationService.saveToFlashcards(
          englishText: _currentEnglishText,
          czechText: translation,
          contextSentence: _effectiveContextSentence,
        );

        if (!mounted) return;

        if (saveResult.isSuccess) {
          setState(() {
            _flashcardId = saveResult.valueOrNull;
            _isSaved = true;
          });
        } else {
          setState(() {
            _isSaved = false;
            _flashcardId = null;
          });
        }
      } else {
        setState(() {
          _isSaved = false;
          _flashcardId = null;
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
        englishText: _currentEnglishText,
        czechText: _translatedText,
        contextSentence: _effectiveContextSentence,
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
      await tts.speak(_currentEnglishText);
    } finally {
      if (mounted) {
        setState(() => _isPlayingTts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanEn = WordTranslationService.cleanWord(_currentEnglishText);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          borderRadius: BorderRadius.circular(24),
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.hairline, width: 1),
          // Dlouhá věta s překladem a slovíčky k výběru se na výšku nevejde (9. 11.)
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Štítek a zavírací křížek ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Překlad do češtiny',
                          style: AppTheme.font(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Zavřít',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.textSecondary,
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
                      style: AppTheme.font(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tlačítko přehrání výslovnosti (Gemini TTS)
                  IconButton(
                    tooltip: 'Přehrát výslovnost',
                    onPressed: _isPlayingTts ? null : _playTts,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceRaised,
                      foregroundColor: AppTheme.textPrimary,
                    ),
                    icon: _isPlayingTts
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textPrimary,
                            ),
                          )
                        : const Icon(Icons.volume_up_rounded, size: 20),
                  ),
                ],
              ),

              // ── Možnost rychlého rozšíření výběru o sousední slova z věty ──────
              if (widget.contextSentence != null && (_canExpandLeft || _canExpandRight)) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_canExpandLeft)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: _isLoading ? null : _expandLeft,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_rounded, size: 12, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+ Slovo vlevo',
                                    style: AppTheme.font(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_canExpandRight)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: _isLoading ? null : _expandRight,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+ Slovo vpravo',
                                    style: AppTheme.font(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),

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
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Překládám v kontextu věty...',
                        style: AppTheme.font(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_errorMessage != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTheme.font(
                          fontSize: 14,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _translate,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textPrimary),
                            const SizedBox(width: 4),
                            Text(
                              'Zkusit znovu',
                              style: AppTheme.font(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _translatedText,
                  style: AppTheme.font(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

              // ── Kontext věty (pokud existuje a neduplikuje označený text) ────────
              if (widget.contextSentence != null &&
                  widget.contextSentence!.trim().isNotEmpty &&
                  widget.contextSentence!.trim().toLowerCase() != _currentEnglishText.trim().toLowerCase()) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Text(
                    '„${widget.contextSentence!.trim()}“',
                    style: AppTheme.font(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // ── Výběr slovíčka z věty do kartiček (Zásada atomických kartiček) ──
              if (_isSentence && !_isLoading && _translatedText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Vyber slovíčko z věty pro kartičku:',
                  style: AppTheme.font(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final word in _sentenceWords)
                      InkWell(
                        onTap: () => _updatePhrase(word, save: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          child: Text(
                            word,
                            style: AppTheme.font(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // ── Spodní akční řádek se stavem kartiček (Smart Flashcards) ───────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isSaved
                      ? AppTheme.success.withValues(alpha: 0.16)
                      : AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSaved
                        ? AppTheme.success.withValues(alpha: 0.35)
                        : AppTheme.hairline,
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
                          ? AppTheme.successLight
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSaved
                            ? 'Uloženo do Smart Flashcards! 🃏'
                            : (_isSentence
                                ? 'Není v kartičkách (vyber slovo výše)'
                                : 'Není v kartičkách'),
                        style: AppTheme.font(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _isSaved
                              ? AppTheme.successLight
                              : AppTheme.textPrimary,
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
                            _isSaved
                                ? 'Vrátit ↩'
                                : (_isSentence ? '+ Uložit celou větu' : '+ Uložit'),
                            style: AppTheme.font(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _isSaved
                                  ? AppTheme.error
                                  : AppTheme.textPrimary,
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
      ),
    );
  }
}
