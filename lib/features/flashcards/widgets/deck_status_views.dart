import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Shrnutí dokončené studijní relace s možností pokračovat dalšími kartičkami.
class ReviewCompletedView extends StatelessWidget {
  final int masteredCount;
  final int againCount;

  /// Kolik kartiček je ještě k opakování (mimo právě dokončenou relaci).
  final int remainingDueCount;
  final bool isGenerating;
  final VoidCallback onPracticeMore;
  final VoidCallback onGenerateFromErrors;

  const ReviewCompletedView({
    super.key,
    required this.masteredCount,
    required this.againCount,
    required this.remainingDueCount,
    required this.isGenerating,
    required this.onPracticeMore,
    required this.onGenerateFromErrors,
  });

  @override
  Widget build(BuildContext context) {
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
                'Skvělá práce! Relace dokončena',
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
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatBadge(
                    icon: Icons.check_circle_rounded,
                    label: '$masteredCount zvládnuto',
                    color: AppTheme.success,
                  ),
                  if (againCount > 0)
                    _StatBadge(
                      icon: Icons.replay_rounded,
                      label: '$againCount zopakováno',
                      color: AppTheme.warning,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (remainingDueCount > 0)
                FilledButton.icon(
                  onPressed: onPracticeMore,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Procvičit další ($remainingDueCount)',
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
                _GenerateFromErrorsButton(
                  isGenerating: isGenerating,
                  onPressed: onGenerateFromErrors,
                  label: 'Zkontrolovat chyby z rozhovorů',
                  fontSize: 13,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prázdný balíček: nic k opakování (nebo zatím žádné kartičky).
class FlashcardsEmptyState extends StatelessWidget {
  final bool hasCards;
  final bool isGenerating;
  final VoidCallback onGenerateFromErrors;

  const FlashcardsEmptyState({
    super.key,
    required this.hasCards,
    required this.isGenerating,
    required this.onGenerateFromErrors,
  });

  @override
  Widget build(BuildContext context) {
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
                hasCards ? 'Máš na dnes splněno!' : 'Žádné kartičky k procvičení',
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
              _GenerateFromErrorsButton(
                isGenerating: isGenerating,
                onPressed: onGenerateFromErrors,
                label: 'Zkontrolovat nové chyby z konverzací',
                fontSize: 13.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateFromErrorsButton extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onPressed;
  final String label;
  final double fontSize;

  const _GenerateFromErrorsButton({
    required this.isGenerating,
    required this.onPressed,
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: isGenerating ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            )
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(
        isGenerating ? 'Kontroluji chyby...' : label,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: fontSize),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
}
