import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../services/gemini/gemini_tts_service.dart';

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
  int _currentIndex = 0;
  bool _isPlayingTts = false;

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
  }

  @override
  void dispose() {
    _flipController.dispose();
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

  Future<void> _playAudio(String text) async {
    HapticFeedback.selectionClick();
    setState(() => _isPlayingTts = true);

    final tts = ref.read(geminiTtsServiceProvider);
    await tts.speak(text);

    if (mounted) {
      setState(() => _isPlayingTts = false);
    }
  }

  Future<void> _answerCard(Flashcard card, int rating, int totalCards) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(sessionRepositoryProvider);
    await repo.reviewFlashcard(flashcardId: card.id, rating: rating);

    if (_flipController.isCompleted) {
      _flipController.reset();
      setState(() => _isBackVisible = false);
    }

    setState(() {
      if (_currentIndex < totalCards - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Smart Flashcards 🃏',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Přidat vlastní kartičku',
            onPressed: () => _showAddFlashcardDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Flashcard>>(
        stream: repo.watchDueFlashcards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dueCards = snapshot.data ?? [];

          if (dueCards.isEmpty) {
            return _buildEmptyState(context);
          }

          final safeIndex = _currentIndex.clamp(0, dueCards.length - 1);
          final currentCard = dueCards[safeIndex];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Indikátor pokroku
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kartička ${safeIndex + 1} z ${dueCards.length}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'K OPAKOVÁNÍ: ${dueCards.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

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

                const SizedBox(height: 16),

                // Spodní ovládací lišta pro hodnocení (pokud je kartička otočená)
                if (_isBackVisible) ...[
                  _buildSrsRatingBar(currentCard, dueCards.length),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _flipCard,
                      icon: const Icon(Icons.flip_rounded),
                      label: Text(
                        'Otočit kartičku (Zobrazit řešení)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard(Flashcard card, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      shadows: AppTheme.glassShadow,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  card.errorType.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(Icons.touch_app_rounded,
                  size: 20, color: AppTheme.mutedTextColor(context)),
            ],
          ),

          // Otázka / Podnět
          Column(
            children: [
              Text(
                'JAK ŘÍCT / OPRAVIT SPRÁVNĚ?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedTextColor(context),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                card.frontText,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                  height: 1.35,
                ),
              ),
              if (card.sourceSentence != null &&
                  card.sourceSentence!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Z rozhovoru: "${card.sourceSentence}"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.mutedTextColor(context),
                    ),
                  ),
                ),
              ],
            ],
          ),

          Text(
            'Klepnutím otočíte kartičku',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.mutedTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(Flashcard card, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      color: AppTheme.success.withValues(alpha: isDark ? 0.12 : 0.05),
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      shadows: AppTheme.glassShadow,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SPRÁVNÉ ŘEŠENÍ ✅',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ),
              // Tlačítko poslechu Gemini TTS
              IconButton.filledTonal(
                icon: Icon(
                  _isPlayingTts
                      ? Icons.volume_up_rounded
                      : Icons.volume_mute_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                onPressed: _isPlayingTts ? null : () => _playAudio(card.backText),
                tooltip: 'Přehrát rodilou výslovnost (Gemini TTS)',
              ),
            ],
          ),

          // Správná věta + vysvětlení
          Column(
            children: [
              Text(
                card.backText,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryLight,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.school_rounded,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        card.explanation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.textColor(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Text(
            'Ohodnoťte, jak snadná pro vás kartička byla:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.mutedTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSrsRatingBar(Flashcard card, int totalCards) {
    return Row(
      children: [
        // Znovu
        Expanded(
          child: _buildRatingButton(
            label: 'Znovu',
            sublabel: '1 den',
            color: AppTheme.error,
            onTap: () => _answerCard(card, 0, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Těžké
        Expanded(
          child: _buildRatingButton(
            label: 'Těžké',
            sublabel: '${(card.intervalDays * 1.2).ceil()} d.',
            color: AppTheme.warning,
            onTap: () => _answerCard(card, 1, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Dobré
        Expanded(
          child: _buildRatingButton(
            label: 'Dobré',
            sublabel: '${(card.intervalDays * 2.0).ceil()} d.',
            color: AppTheme.primary,
            onTap: () => _answerCard(card, 2, totalCards),
          ),
        ),
        const SizedBox(width: 8),
        // Snadné
        Expanded(
          child: _buildRatingButton(
            label: 'Snadné',
            sublabel: '${(card.intervalDays * 3.0).ceil()} d.',
            color: AppTheme.success,
            onTap: () => _answerCard(card, 3, totalCards),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              sublabel,
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 44,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Máš na dnes splněno! 🎉',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Všechny kartičky k dnešnímu opakování jsou hotové. Nové kartičky se automaticky vytvoří z tvých chyb v konverzacích nebo si můžeš přidat vlastní tlačítkem + nahoře.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _showAddFlashcardDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Vytvořit novou kartičku'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFlashcardDialog(BuildContext context) {
    final frontController = TextEditingController();
    final backController = TextEditingController();
    final explanationController = TextEditingController();
    String errorType = 'grammar';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Nová Smart Flashcard 🃏',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: frontController,
                  decoration: const InputDecoration(
                    labelText: 'Otázka / Český text',
                    hintText: 'např. Včera jsem šel do kina.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: backController,
                  decoration: const InputDecoration(
                    labelText: 'Správné anglické znění',
                    hintText: 'např. I went to the cinema yesterday.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: explanationController,
                  decoration: const InputDecoration(
                    labelText: 'Vysvětlení / Poznámka',
                    hintText: 'např. Minulý čas od go je went.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: errorType,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                  items: const [
                    DropdownMenuItem(
                        value: 'grammar', child: Text('Gramatika')),
                    DropdownMenuItem(
                        value: 'vocabulary', child: Text('Slovní zásoba')),
                    DropdownMenuItem(
                        value: 'preposition', child: Text('Předložka')),
                    DropdownMenuItem(
                        value: 'pronunciation', child: Text('Výslovnost')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => errorType = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Zrušit'),
            ),
            FilledButton(
              onPressed: () async {
                final front = frontController.text.trim();
                final back = backController.text.trim();
                final exp = explanationController.text.trim();

                if (front.isEmpty || back.isEmpty) return;

                final repo = ref.read(sessionRepositoryProvider);
                await repo.addFlashcard(
                  frontText: front,
                  backText: back,
                  explanation: exp.isEmpty ? 'Vlastní kartička' : exp,
                  errorType: errorType,
                );

                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kartička byla úspěšně přidána! 🎯'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Přidat'),
            ),
          ],
        ),
      ),
    );
  }
}
