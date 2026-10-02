import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/models/flashcard_stats.dart';
import '../../services/gemini/gemini_batch_client.dart';
import '../../services/gemini/gemini_providers.dart';
import '../../services/gemini/pronunciation_service.dart';
import 'answer_recorder.dart';
import 'card_front_resolver.dart';
import 'flashcards_controller.dart';
import 'review_session.dart';
import 'typed_answer.dart';
import 'widgets/answer_input_bar.dart';
import 'widgets/deck_status_views.dart';
import 'widgets/flashcard_back.dart';
import 'widgets/flashcard_front.dart';
import 'widgets/review_session_header.dart';
import 'widgets/srs_rating_bar.dart';

/// Obrazovka pro procvičování kartiček s intervalovým opakováním (Smart Flashcards).
class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late final FlashcardsController _controller;
  late final AnswerRecorder _recorder;
  late final CardFrontResolver _frontResolver;

  bool _isBackVisible = false;
  bool _isPlayingTts = false;
  bool _isGenerating = false;
  bool _migrationStarted = false;

  /// Stabilní studijní relace (řeší odčítání 1 z 20, 1 z 19...); null = sestavit znovu.
  ReviewSession? _session;

  // Stav pro hlasové diktování a hodnocení výslovnosti
  bool _isRecording = false;
  bool _isEvaluatingSpeech = false;
  double _recordingVolume = 0.0;
  PronunciationAnalysis? _lastPronunciation;

  // Písemná odpověď nebo „Nevím“ místo mluvené odpovědi
  TypedAnswer? _typedAnswer;
  bool _gaveUp = false;

  /// Student se pokusil odpovědět; teprve pak jde kartičku otočit a ohodnotit.
  bool get _hasAnswered => _lastPronunciation != null || _typedAnswer != null || _gaveUp;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(flashcardsControllerProvider);
    _recorder = _controller.createRecorder();
    _frontResolver = _controller.createFrontResolver(
      onTranslated: () {
        if (mounted) setState(() {});
      },
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    )..addListener(() {
        if (_flipAnimation.value >= 0.5 && !_isBackVisible) {
          setState(() => _isBackVisible = true);
        } else if (_flipAnimation.value < 0.5 && _isBackVisible) {
          setState(() => _isBackVisible = false);
        }
      });

    // Na pozadí vyčistíme neplatné kartičky (leaky) a přeložíme staré kartičky
    // s chybnou angličtinou do češtiny
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.cleanupInvalidCards();
      _startMigrationOnce(_controller.gemini);
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Spustí jednorázovou migraci starých zadání, jakmile je k dispozici Gemini klient.
  void _startMigrationOnce(GeminiBatchClient? gemini) {
    if (gemini == null || _migrationStarted) return;
    _migrationStarted = true;
    _controller.migrateLegacyCards(gemini);
  }

  void _flipCard() {
    // Na řešení se nejde podívat bez pokusu o odpověď
    if (!_flipController.isCompleted && !_hasAnswered) return;
    HapticFeedback.selectionClick();
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _resetFlip() {
    if (_flipController.isCompleted) {
      _flipController.reset();
      setState(() => _isBackVisible = false);
    }
  }

  void _clearAnswerState() {
    _lastPronunciation = null;
    _typedAnswer = null;
    _gaveUp = false;
    _recorder.clear();
    _isRecording = false;
    _isEvaluatingSpeech = false;
  }

  void _submitTypedAnswer(Flashcard card, String text) {
    FocusScope.of(context).unfocus();
    setState(() => _typedAnswer = TypedAnswer.evaluate(text, card.backText));
    _flipCard();
  }

  void _giveUp() {
    FocusScope.of(context).unfocus();
    setState(() => _gaveUp = true);
    _flipCard();
  }

  Future<void> _generateFromErrors() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await _controller.generateFromErrors();

      if (!mounted) return;

      res.fold(
        (count) {
          if (count > 0) {
            // Relaci sestavíme znovu i s nově vytvořenými kartičkami
            setState(() => _session = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vytvořeno $count nových kartiček z tvých chyb!',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Všechny tvé zaznamenané chyby už v kartičkách máš!',
                  style: GoogleFonts.plusJakartaSans(),
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba: ${failure.message}'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    try {
      setState(() {
        _isRecording = true;
        _isEvaluatingSpeech = false;
        _lastPronunciation = null;
        _recordingVolume = 0.0;
      });

      await _recorder.start(onVolume: (vol) {
        if (mounted) {
          setState(() => _recordingVolume = vol);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nelze spustit mikrofon: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording(Flashcard card) async {
    HapticFeedback.mediumImpact();

    try {
      await _recorder.stop();

      setState(() {
        _isRecording = false;
        _recordingVolume = 0.0;
      });

      if (_recorder.isTooShort) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nahrávka byla příliš krátká, zkuste to znovu.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() => _isEvaluatingSpeech = true);

      final result = await _controller.evaluateAnswer(
        audio: _recorder.bytes,
        card: card,
        prompt: _frontResolver.resolve(card),
      );

      if (mounted) {
        setState(() {
          _isEvaluatingSpeech = false;
          _lastPronunciation = result;
        });

        if (result != null) {
          HapticFeedback.heavyImpact();
          // Automaticky po 1.5 sekundy otočíme kartičku s 3D animací, aby student viděl správné řešení a poslech
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && !_isBackVisible) {
              _flipCard();
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nepodařilo se vyhodnotit výslovnost. Zkontrolujte API klíč.'),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isEvaluatingSpeech = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při nahrávání: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _playAudio(String text) async {
    HapticFeedback.selectionClick();
    setState(() => _isPlayingTts = true);

    final success = await _controller.speak(text);

    if (mounted) {
      setState(() => _isPlayingTts = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepodařilo se přehrát výslovnost. Zkontrolujte připojení.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _answerCard(Flashcard card, int rating) async {
    HapticFeedback.mediumImpact();
    await _controller.review(card, rating);

    _resetFlip();

    setState(() {
      _clearAnswerState();
      _session?.recordAnswer(card, rating);
    });
  }

  Future<void> _deleteCurrentCard(Flashcard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Smazat kartičku?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Opravdu chceš tuto kartičku trvale smazat?\n\n"${card.backText}"',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    await _controller.delete(card);

    _resetFlip();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kartička byla smazána.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _clearAnswerState();
        _session?.remove(card.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jakmile je k dispozici Gemini klient (po načtení API klíče), na pozadí zmigrujeme staré kartičky do češtiny
    final gemini = ref.watch(geminiBatchClientProvider);
    if (gemini != null && !_migrationStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMigrationOnce(gemini));
    }
    ref.listen<GeminiBatchClient?>(geminiBatchClientProvider, (previous, next) {
      _startMigrationOnce(next);
    });

    final stats = ref.watch(flashcardStatsProvider).value ?? const FlashcardStats.empty();
    final dueAsync = ref.watch(dueFlashcardsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (context) {
            if (dueAsync.isLoading && !dueAsync.hasValue && _session == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final dueCards = dueAsync.value ?? [];

            // Inicializace relace při prvním načtení nebo po resetu
            final session = _session ??= ReviewSession(dueCards);

            // Pokud nemáme vůbec žádné kartičky k procvičení
            if (session.isEmpty && dueCards.isEmpty) {
              return FlashcardsEmptyState(
                hasCards: stats.totalCards > 0,
                isGenerating: _isGenerating,
                onGenerateFromErrors: _generateFromErrors,
              );
            }

            // Pokud je relace dokončena
            if (session.isFinished) {
              return ReviewCompletedView(
                masteredCount: session.masteredCount,
                againCount: session.againCount,
                remainingDueCount: dueCards.length,
                isGenerating: _isGenerating,
                onPracticeMore: () => setState(() => _session = ReviewSession(dueCards)),
                onGenerateFromErrors: _generateFromErrors,
              );
            }

            return _buildReview(session);
          },
        ),
      ),
    );
  }

  Widget _buildReview(ReviewSession session) {
    final currentCard = session.current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Sjednocený indikátor pokroku v dnešní relaci
          ReviewSessionHeader(
            currentIndex: session.index,
            totalCards: session.total,
            masteredCount: session.masteredCount,
          ),

          const SizedBox(height: 8),

          // 3D Animovaná Kartička
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final angle = _flipAnimation.value * math.pi;
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspektiva
                    ..rotateY(angle);

                  return Transform(
                    transform: transform,
                    alignment: Alignment.center,
                    child: _isBackVisible
                        ? Transform(
                            transform: Matrix4.identity()..rotateY(math.pi),
                            alignment: Alignment.center,
                            child: FlashcardBack(
                              card: currentCard,
                              lastPronunciation: _lastPronunciation,
                              typedAnswer: _typedAnswer,
                              isPlayingTts: _isPlayingTts,
                              onPlayAudio: () => _playAudio(currentCard.backText),
                              onDelete: () => _deleteCurrentCard(currentCard),
                              onFlip: _flipCard,
                            ),
                          )
                        : _buildFront(currentCard),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Spodní ovládací lišta pro hodnocení nebo otočení
          if (_isBackVisible) ...[
            SrsRatingBar(
              card: currentCard,
              answerScore: _lastPronunciation?.overallScore ?? _typedAnswer?.score,
              againOnly: _gaveUp,
              onRate: (rating) => _answerCard(currentCard, rating),
            ),
          ] else if (!_hasAnswered) ...[
            AnswerInputBar(
              key: ValueKey(currentCard.id),
              enabled: !_isRecording && !_isEvaluatingSpeech,
              onSubmit: (text) => _submitTypedAnswer(currentCard, text),
              onGiveUp: _giveUp,
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _flipCard,
                icon: const Icon(Icons.flip_to_back_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Otočit kartičku (Zobrazit řešení)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFront(Flashcard card) {
    final frontText = _frontResolver.resolve(card);
    return FlashcardFront(
      frontText: frontText,
      isTranslating: frontText == CardFrontResolver.translatingPlaceholder,
      lastPronunciation: _lastPronunciation,
      isEvaluatingSpeech: _isEvaluatingSpeech,
      isRecording: _isRecording,
      recordingVolume: _recordingVolume,
      onStartRecording: _startRecording,
      onStopRecording: () => _stopRecording(card),
      onFlip: _flipCard,
    );
  }
}
