import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/glass_container.dart';
import '../../data/database/app_database.dart';
import '../../data/models/flashcard_stats.dart';
import '../../data/repositories/session_repository.dart';
import '../../providers/audio_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../services/gemini/gemini_batch_client.dart';
import '../../services/gemini/gemini_tts_service.dart';
import '../../services/gemini/pronunciation_service.dart';

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

  bool _isBackVisible = false;
  bool _isPlayingTts = false;
  bool _isGenerating = false;
  bool _migrationStarted = false;
  final Map<int, String> _resolvedCzechFronts = {};
  final Set<int> _translatingCardIds = {};

  // Stabilní studijní relace (řeší odčítání 1 z 20, 1 z 19...)
  List<Flashcard>? _sessionQueue;
  int _sessionIndex = 0;
  int _sessionMasteredCount = 0;
  int _sessionAgainCount = 0;
  bool _sessionCompleted = false;

  // Stav pro hlasové diktování a hodnocení výslovnosti
  bool _isRecording = false;
  bool _isEvaluatingSpeech = false;
  double _recordingVolume = 0.0;
  final List<int> _recordedBytes = [];
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<double>? _volumeSub;
  PronunciationAnalysis? _lastPronunciation;

  Future<void> _generateFromErrors() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final gemini = ref.read(geminiBatchClientProvider);
      final res = await repo.generateFlashcardsFromErrors(
        limit: 15,
        geminiClient: gemini,
      );

      if (!mounted) return;

      res.fold(
        (count) {
          if (count > 0) {
            setState(() {
              _sessionQueue = null;
              _sessionCompleted = false;
              _sessionIndex = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vytvořeno $count nových kartiček z tvých chyb! 🎯',
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
                  'Všechny tvé zaznamenané chyby už v kartičkách máš! 👍',
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

  @override
  void initState() {
    super.initState();
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

    // Na pozadí zkontrolujeme a automaticky přeložíme staré kartičky s chybnou angličtinou do češtiny
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gemini = ref.read(geminiBatchClientProvider);
      if (gemini != null) {
        ref.read(sessionRepositoryProvider).autoMigrateLegacyCardsToCzech(gemini);
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _audioSub?.cancel();
    _volumeSub?.cancel();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.selectionClick();
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Future<void> _startRecording(Flashcard card) async {
    HapticFeedback.mediumImpact();
    final capture = ref.read(audioCaptureServiceProvider);

    try {
      _recordedBytes.clear();
      setState(() {
        _isRecording = true;
        _isEvaluatingSpeech = false;
        _lastPronunciation = null;
        _recordingVolume = 0.0;
      });

      _audioSub?.cancel();
      _audioSub = capture.audioStream.listen((chunk) {
        _recordedBytes.addAll(chunk);
      });

      _volumeSub?.cancel();
      _volumeSub = capture.volumeStream.listen((vol) {
        if (mounted) {
          setState(() => _recordingVolume = vol);
        }
      });

      await capture.startRecording();
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
    final capture = ref.read(audioCaptureServiceProvider);

    try {
      await capture.stopRecording();
      _audioSub?.cancel();
      _volumeSub?.cancel();

      setState(() {
        _isRecording = false;
        _recordingVolume = 0.0;
      });

      if (_recordedBytes.length < 1600) {
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

      final pronService = ref.read(pronunciationServiceProvider);
      final result = await pronService.evaluateSpokenAnswer(
        audioBytes: List<int>.from(_recordedBytes),
        expectedEnglish: card.backText,
        promptContext: _getDisplayFrontText(card),
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

    final tts = ref.read(geminiTtsServiceProvider);
    final success = await tts.speak(text);

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

  Future<void> _answerCard(Flashcard card, int rating, int totalCards) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(sessionRepositoryProvider);
    await repo.reviewFlashcard(flashcardId: card.id, rating: rating);

    if (rating >= 2) {
      _sessionMasteredCount++;
    } else if (rating == 0) {
      _sessionAgainCount++;
      _sessionQueue?.add(card);
    }

    if (_flipController.isCompleted) {
      _flipController.reset();
      setState(() => _isBackVisible = false);
    }

    setState(() {
      _lastPronunciation = null;
      _recordedBytes.clear();
      _isRecording = false;
      _isEvaluatingSpeech = false;
      _sessionIndex++;
      if (_sessionQueue != null && _sessionIndex >= _sessionQueue!.length) {
        _sessionCompleted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);
    final gemini = ref.watch(geminiBatchClientProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Jakmile je k dispozici Gemini klient (po načtení API klíče), automaticky na pozadí zmigrujeme staré kartičky do češtiny
    if (gemini != null && !_migrationStarted) {
      _migrationStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.autoMigrateLegacyCardsToCzech(gemini);
      });
    }

    ref.listen<GeminiBatchClient?>(geminiBatchClientProvider, (previous, next) {
      if (next != null && !_migrationStarted) {
        _migrationStarted = true;
        repo.autoMigrateLegacyCardsToCzech(next);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<FlashcardStats>(
        stream: repo.watchFlashcardStats(),
        builder: (context, statsSnapshot) {
          final stats = statsSnapshot.data ?? const FlashcardStats.empty();

          return StreamBuilder<List<Flashcard>>(
            stream: repo.watchDueFlashcards(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData &&
                  _sessionQueue == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final dueCards = snapshot.data ?? [];

              // Inicializace relace při prvním načtení nebo po resetu
              if (_sessionQueue == null) {
                if (dueCards.isNotEmpty) {
                  _sessionQueue = List<Flashcard>.from(dueCards);
                  _sessionIndex = 0;
                  _sessionMasteredCount = 0;
                  _sessionAgainCount = 0;
                  _sessionCompleted = false;
                } else {
                  _sessionQueue = [];
                  _sessionCompleted = true;
                }
              }

              // Pokud nemáme vůbec žádné kartičky k procvičení
              if (_sessionQueue!.isEmpty && dueCards.isEmpty) {
                return _buildEmptyState(context, stats);
              }

              // Pokud je relace dokončena
              if (_sessionCompleted || _sessionIndex >= _sessionQueue!.length) {
                return _buildSessionCompletedState(
                  context,
                  stats,
                  _sessionMasteredCount,
                  _sessionAgainCount,
                  dueCards,
                );
              }

              final currentCard = _sessionQueue![_sessionIndex];
              final totalInSession = _sessionQueue!.length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // Sjednocený indikátor pokroku v dnešní relaci
                    _buildSessionHeader(
                      context: context,
                      currentIndex: _sessionIndex,
                      totalCards: totalInSession,
                      masteredCount: _sessionMasteredCount,
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
                                      child: _buildBackCard(currentCard, isDark),
                                    )
                                  : _buildFrontCard(currentCard, isDark),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Spodní ovládací lišta pro hodnocení nebo otočení
                    if (_isBackVisible) ...[
                      _buildSrsRatingBar(currentCard, totalInSession),
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
            },
          );
        },
      ),
    ),
  );
  }

  Widget _buildSessionHeader({
    required BuildContext context,
    required int currentIndex,
    required int totalCards,
    required int masteredCount,
  }) {
    final double progress = totalCards > 0 ? (currentIndex + 1) / totalCards : 0.0;
    final percent = (progress * 100).round();
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.glassLightColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor(context)),
        boxShadow: AppTheme.glassShadowsLight(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kartička ${currentIndex + 1} z $totalCards',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (masteredCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 11, color: AppTheme.success),
                          const SizedBox(width: 3),
                          Text(
                            '$masteredCount zvládnuto',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '$percent%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCompletedState(
    BuildContext context,
    FlashcardStats stats,
    int masteredCount,
    int againCount,
    List<Flashcard> remainingDueCards,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success.withValues(alpha: 0.15),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Skvělá práce! Relace dokončena 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Všechny kartičky z této studijní dávky máš úspěšně procvičené.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatBadge(
                    icon: Icons.check_circle_rounded,
                    label: '$masteredCount zvládnuto',
                    color: AppTheme.success,
                  ),
                  if (againCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      icon: Icons.replay_rounded,
                      label: '$againCount zopakováno',
                      color: AppTheme.warning,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (remainingDueCards.isNotEmpty)
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _sessionQueue = List<Flashcard>.from(remainingDueCards);
                      _sessionIndex = 0;
                      _sessionMasteredCount = 0;
                      _sessionAgainCount = 0;
                      _sessionCompleted = false;
                    });
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Procvičit další (${remainingDueCards.length})',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Nové kartičky se automaticky tvoří z chyb při konverzaci v hlasovém tutorovi.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppTheme.mutedTextColor(context),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: _isGenerating ? null : _generateFromErrors,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    _isGenerating ? 'Kontroluji chyby...' : 'Zkontrolovat chyby z rozhovorů',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPronunciationBadge(PronunciationAnalysis analysis) {
    final score = (analysis.overallScore * 100).round();
    final Color scoreColor = score >= 85
        ? const Color(0xFF10B981)
        : (score >= 65 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14, color: scoreColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Výslovnost: $score %',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordAssessmentPills(PronunciationAnalysis analysis) {
    if (analysis.words.isEmpty) {
      return Text(
        analysis.transcribedText,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor(context),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: analysis.words.map((w) {
        final isAcc = w.isAccurate;
        final wordColor = isAcc ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        final bgColor = isAcc
            ? const Color(0xFF10B981).withValues(alpha: 0.16)
            : const Color(0xFFEF4444).withValues(alpha: 0.18);
        final borderColor = isAcc
            ? const Color(0xFF10B981).withValues(alpha: 0.35)
            : const Color(0xFFEF4444).withValues(alpha: 0.45);

        return Tooltip(
          message: (w.phoneticTip != null && w.phoneticTip!.isNotEmpty)
              ? w.phoneticTip!
              : (isAcc ? 'Správná výslovnost ✅' : 'Nepřesná výslovnost ⚠️'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAcc ? Icons.check_rounded : Icons.priority_high_rounded,
                  size: 13,
                  color: wordColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    w.recognizedWord.isNotEmpty ? w.recognizedWord : w.expectedWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: wordColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getDisplayFrontText(Flashcard card) {
    // 1. Pokud již máme přeloženo v lokální paměti této obrazovky
    if (_resolvedCzechFronts.containsKey(card.id)) {
      return _resolvedCzechFronts[card.id]!;
    }

    final raw = card.frontText.trim();

    // 2. Pokud je text již v čisté češtině (žádné legacy šablony ani anglické uvozovky)
    if (!SessionRepository.isLegacyOrEnglishFront(
      raw,
      backText: card.backText,
      sourceSentence: card.sourceSentence,
    )) {
      return raw;
    }

    // 3. Pokus o okamžitou extrakci českého překladu z vysvětlení (např. "(jeden měsíc)")
    final extracted = SessionRepository.extractCzechFromExplanation(card.explanation);
    if (extracted != null && extracted.isNotEmpty) {
      _resolvedCzechFronts[card.id] = extracted;
      // Na pozadí rovnou uložíme do SQLite, ať je to trvalé
      ref.read(sessionRepositoryProvider).updateFlashcardFrontText(card.id, extracted);
      return extracted;
    }

    // 4. Pokud je kartička legacy/anglická a ještě se nepřekládá, spustíme okamžitý on-demand překlad
    final gemini = ref.read(geminiBatchClientProvider);
    if (gemini != null) {
      _triggerOnDemandCardTranslation(card);
      // 5. Dokud překlad běží, V ŽÁDNÉM PŘÍPADĚ nezobrazujeme angličtinu ani chybnou šablonu!
      return 'Překládám zadání do češtiny... ⏳';
    }

    // 6. Gemini není k dispozici — zobrazíme surový text (lepší než nekonečný spinner)
    return raw;
  }

  void _triggerOnDemandCardTranslation(Flashcard card) {
    if (_translatingCardIds.contains(card.id)) return;
    final gemini = ref.read(geminiBatchClientProvider);
    if (gemini == null) return;

    _translatingCardIds.add(card.id);

    gemini.sendMessage(
      'Přelož tuto anglickou větu/frázi do přirozené češtiny (vrať VÝHRADNĚ čistý český překlad bez uvozovek a bez vysvětlování): "${card.backText}"',
    ).then((translated) {
      final clean = translated.trim().replaceAll('"', '').replaceAll('\n', ' ');
      if (clean.isNotEmpty && !clean.startsWith('❌')) {
        _resolvedCzechFronts[card.id] = clean;
        ref.read(sessionRepositoryProvider).updateFlashcardFrontText(card.id, clean);
        if (mounted) setState(() {});
      }
    }).catchError((err) {
      L.w('On-demand překlad kartičky #${card.id} selhal: $err');
    }).whenComplete(() {
      _translatingCardIds.remove(card.id);
    });
  }

  Widget _buildFrontCard(Flashcard card, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
      shadows: AppTheme.glassShadow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
          // Horní lišta líce
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_lastPronunciation != null)
                _buildPronunciationBadge(_lastPronunciation!)
              else
                Tooltip(
                  message: 'Klepnutím otočíte kartičku',
                  child: Icon(Icons.touch_app_rounded,
                      size: 20, color: AppTheme.mutedTextColor(context)),
                ),
            ],
          ),

          // Zadání otázky v češtině (žádná matoucí chybná angličtina!)
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate_rounded, size: 13, color: AppTheme.mutedTextColor(context)),
                    const SizedBox(width: 5),
                    Text(
                      'PŘELOŽ DO ANGLIČTINY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.mutedTextColor(context),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final frontText = _getDisplayFrontText(card);
                  final isTranslating = frontText.startsWith('Překládám');
                  if (isTranslating) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            frontText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.mutedTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Text(
                    frontText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                      height: 1.35,
                    ),
                  );
                },
              ),
            ],
          ),

          // Interaktivní mluvený trénink
          Column(
            children: [
              if (_isEvaluatingSpeech) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Hodnotím výslovnost...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isRecording) ...[
                GestureDetector(
                  onTap: () => _stopRecording(card),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 62 + (_recordingVolume * 20).clamp(0.0, 16.0),
                        height: 62 + (_recordingVolume * 20).clamp(0.0, 16.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.error,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.error.withValues(
                                  alpha: (0.4 + _recordingVolume * 0.4).clamp(0.3, 0.8)),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'Mluvte... Klepněte pro stop',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_lastPronunciation != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildWordAssessmentPills(_lastPronunciation!),
                      if (_lastPronunciation!.feedback.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _lastPronunciation!.feedback,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.mutedTextColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _flipCard,
                  icon: const Icon(Icons.flip_rounded, size: 16),
                  label: const Text('Zobrazit řešení'),
                ),
              ] else ...[
                // Výchozí stav: Kruhové tlačítko mikrofonu s animací
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _startRecording(card),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Klepněte a odpovězte hlasem',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextButton(
                      onPressed: _flipCard,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'nebo otočit bez mluvení',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.mutedTextColor(context),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  ),
);
},
),
);
}

  Widget _buildBackCard(Flashcard card, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
      color: AppTheme.success.withValues(alpha: isDark ? 0.12 : 0.05),
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      shadows: AppTheme.glassShadow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.success),
                      const SizedBox(width: 5),
                      Text(
                        'SPRÁVNÉ ŘEŠENÍ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Funkční tlačítko poslechu Gemini TTS
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: IconButton(
                  icon: _isPlayingTts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                  onPressed: _isPlayingTts ? null : () => _playAudio(card.backText),
                  tooltip: 'Přehrát rodilou výslovnost (Gemini TTS)',
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          // Správná věta + srovnání s výslovností
          Column(
            children: [
              Text(
                card.backText,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.primaryLight : AppTheme.primaryDark,
                  height: 1.3,
                ),
              ),
              if (_lastPronunciation != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: _buildPronunciationBadge(_lastPronunciation!),
                      ),
                      const SizedBox(height: 8),
                      _buildWordAssessmentPills(_lastPronunciation!),
                    ],
                  ),
                ),
              ],
              // Nápověda a vysvětlení správného tvaru
              if (card.explanation.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 16, color: AppTheme.warning),
                          const SizedBox(width: 6),
                          Text(
                            'NÁPOVĚDA A VYSVĚTLENÍ:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.explanation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppTheme.textColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (card.sourceSentence != null && card.sourceSentence!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 14, color: AppTheme.mutedTextColor(context)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Původně v konverzaci: "${card.sourceSentence}"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.mutedTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Tlačítko otočení zpět
          TextButton.icon(
            onPressed: _flipCard,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Otočit zpět na zadání'),
          ),
        ],
      ),
    ),
  ),
);
},
),
);
}

  Widget _buildSrsRatingBar(Flashcard card, int totalCards) {
    final score = _lastPronunciation?.overallScore;
    final int recommendedRating;
    if (score != null) {
      if (score >= 0.85) {
        recommendedRating = 3; // Snadné
      } else if (score >= 0.65) {
        recommendedRating = 2; // Dobré
      } else if (score >= 0.40) {
        recommendedRating = 1; // Těžké
      } else {
        recommendedRating = 0; // Znovu
      }
    } else {
      recommendedRating = -1;
    }

    return Row(
      children: [
        // Znovu
        Expanded(
          child: _buildRatingButton(
            icon: Icons.replay_rounded,
            label: 'Znovu',
            sublabel: '1 den',
            color: AppTheme.error,
            isRecommended: recommendedRating == 0,
            onTap: () => _answerCard(card, 0, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Těžké
        Expanded(
          child: _buildRatingButton(
            icon: Icons.sentiment_dissatisfied_rounded,
            label: 'Těžké',
            sublabel: '${(card.intervalDays * 1.2).ceil()} d.',
            color: AppTheme.warning,
            isRecommended: recommendedRating == 1,
            onTap: () => _answerCard(card, 1, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Dobré
        Expanded(
          child: _buildRatingButton(
            icon: Icons.sentiment_satisfied_rounded,
            label: 'Dobré',
            sublabel: '${(card.intervalDays * 2.0).ceil()} d.',
            color: AppTheme.primary,
            isRecommended: recommendedRating == 2,
            onTap: () => _answerCard(card, 2, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Snadné
        Expanded(
          child: _buildRatingButton(
            icon: Icons.sentiment_very_satisfied_rounded,
            label: 'Snadné',
            sublabel: '${(card.intervalDays * 3.0).ceil()} d.',
            color: AppTheme.success,
            isRecommended: recommendedRating == 3,
            onTap: () => _answerCard(card, 3, totalCards),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isRecommended
              ? color.withValues(alpha: 0.22)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecommended ? color : color.withValues(alpha: 0.35),
            width: isRecommended ? 1.8 : 1.0,
          ),
          boxShadow: isRecommended
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecommended)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'DOPORUČENO',
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, FlashcardStats stats) {
    final hasCards = stats.totalCards > 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (hasCards ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.12),
                ),
                child: Icon(
                  hasCards ? Icons.check_circle_outline_rounded : Icons.forum_rounded,
                  size: 44,
                  color: hasCards ? AppTheme.success : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasCards ? 'Máš na dnes splněno! 🎉' : 'Žádné kartičky k procvičení',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hasCards
                    ? 'Všechny kartičky k dnešnímu opakování máš hotové.\nNová slovíčka a fráze se ti sem automaticky ukládají z chyb při konverzacích s tutorem.'
                    : 'Kartičky vznikají automaticky z chyb během rozhovorů v záložce Voice.\nZačni mluvit s tutorem a nová slovíčka se ti sem sama vytvoří!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: _isGenerating ? null : _generateFromErrors,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  _isGenerating ? 'Kontroluji chyby...' : 'Zkontrolovat nové chyby z konverzací',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
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
