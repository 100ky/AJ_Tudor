import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';

/// Prázdný stav drilu: zaměření na chyby studenta a rychlé spuštění.
class DrillEmptyState extends StatelessWidget {
  final List<String> errors;
  final String level;
  final bool isLoading;

  /// Spustí dril na opakující se chyby.
  final VoidCallback onStart;

  /// Spustí dril na konkrétní téma.
  final ValueChanged<String> onStartTopic;

  const DrillEmptyState({
    super.key,
    required this.errors,
    required this.level,
    required this.isLoading,
    required this.onStart,
    required this.onStartTopic,
  });

  @override
  Widget build(BuildContext context) {
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
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.hairline),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 32,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Gramatická cvičebna',
              style: AppTheme.font(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tutor ti zadá 3 krátké české věty k překladu zaměřené na tvé chyby, ihned je zkontroluje a vysvětlí gramatická pravidla.',
              textAlign: TextAlign.center,
              style: AppTheme.font(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Karta zaměření drilu
            _FocusCard(errors: errors, level: level),

            const SizedBox(height: 18),

            // Hlavní tlačítko pro spuštění drilu
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onStart,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.background,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(isLoading ? 'Připravuji dril...' : 'Spustit gramatický dril'),
              ),
            ),

            const SizedBox(height: 14),

            // Rychlé chipsy pro konkrétní témata
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final topic in const [
                  'Předpřítomný čas (Present Perfect)',
                  'Podmínkové věty (Conditionals)',
                  'Předložky času a místa (in, at, on)',
                ])
                  ActionChip(
                    onPressed: isLoading ? null : () => onStartTopic(topic),
                    avatar: const Icon(Icons.bolt_rounded, size: 15, color: AppTheme.textSecondary),
                    label: Text(
                      topic,
                      style: AppTheme.font(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  final List<String> errors;
  final String level;

  const _FocusCard({required this.errors, required this.level});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.hairline),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zaměření pro úroveň $level',
            style: AppTheme.font(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (errors.isNotEmpty) ...[
            Text(
              'Tvé zaznamenané opakující se chyby:',
              style: AppTheme.font(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: errors.map((e) {
                final clean = e.length > 50 ? '${e.substring(0, 48)}...' : e;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    clean,
                    style: AppTheme.font(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Text(
              'Zatím nemáš nasbírané chyby z hlasových lekcí. Tutor pro tebe vybere typické gramatické jevy pro úroveň $level.',
              style: AppTheme.font(
                fontSize: 13,
                color: AppTheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
