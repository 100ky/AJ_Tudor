import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
import '../../../data/data_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../services/gemini/gemini_tts_service.dart';

/// Prohlížeč všech uložených kartiček s vyhledáváním, poslechem a mazáním.
class AllFlashcardsSheet extends ConsumerStatefulWidget {
  const AllFlashcardsSheet({super.key});

  /// Otevře spodní list se seznamem všech kartiček.
  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AllFlashcardsSheet(),
    );
  }

  @override
  ConsumerState<AllFlashcardsSheet> createState() => _AllFlashcardsSheetState();
}

class _AllFlashcardsSheetState extends ConsumerState<AllFlashcardsSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _playingCardId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playTts(Flashcard card) async {
    if (_playingCardId != null) return;
    HapticFeedback.selectionClick();
    setState(() => _playingCardId = card.id);
    try {
      await ref.read(geminiTtsServiceProvider).speak(card.backText);
    } finally {
      if (mounted) setState(() => _playingCardId = null);
    }
  }

  Future<void> _deleteCard(Flashcard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smazat kartičku?'),
        content: Text('Opravdu chceš trvale smazat „${card.backText}“?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Zrušit')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    await ref.read(flashcardRepositoryProvider).deleteFlashcard(card.id);
  }

  (String label, Color color) _statusInfo(Flashcard card, DateTime now) {
    if (card.masteryScore >= 0.8) {
      return ('Zvládnuto', AppTheme.success);
    }
    if (!card.nextReviewAt.isAfter(now)) {
      return ('Dnes', AppTheme.accent);
    }
    final days = card.nextReviewAt.difference(now).inDays.clamp(1, 365);
    return ('Za $days ${czechPlural(days, 'den', 'dny', 'dní')}', AppTheme.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(allFlashcardsProvider);
    final cards = cardsAsync.value ?? const <Flashcard>[];
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? cards
        : cards
            .where((c) => c.backText.toLowerCase().contains(q) || c.frontText.toLowerCase().contains(q))
            .toList();
    final now = DateTime.now();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.hairline)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Všechny kartičky (${cards.length})',
                      style: AppTheme.font(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zavřít',
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: AppTheme.font(fontSize: 14.5, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Hledat česky nebo anglicky…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Vymazat hledání',
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: cardsAsync.isLoading && cards.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              cards.isEmpty
                                  ? 'Zatím nemáš žádné uložené kartičky.'
                                  : 'Žádná kartička neodpovídá hledání.',
                              style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(color: AppTheme.hairline, height: 1),
                          itemBuilder: (context, index) {
                            final card = filtered[index];
                            final (statusLabel, statusColor) = _statusInfo(card, now);
                            final isPlaying = _playingCardId == card.id;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.backText,
                                          style: AppTheme.font(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          card.frontText,
                                          style: AppTheme.font(
                                            fontSize: 13.5,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusLabel,
                                          style: AppTheme.font(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Přehrát výslovnost',
                                    onPressed: isPlaying ? null : () => _playTts(card),
                                    icon: isPlaying
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.volume_up_rounded, size: 20, color: AppTheme.textSecondary),
                                  ),
                                  IconButton(
                                    tooltip: 'Smazat kartičku',
                                    onPressed: () => _deleteCard(card),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textTertiary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
