import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
            _FocusCard(errors: errors, level: level),

            const SizedBox(height: 18),

            // Hlavní tlačítko pro spuštění drilu
            GestureDetector(
              onTap: isLoading ? null : onStart,
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
                    if (isLoading) ...[
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
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
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
                for (final topic in const [
                  'Předpřítomný čas (Present Perfect)',
                  'Podmínkové věty (Conditionals)',
                  'Předložky času a místa (in, at, on)',
                ])
                  ActionChip(
                    onPressed: isLoading ? null : () => onStartTopic(topic),
                    avatar: Icon(Icons.bolt_rounded, size: 14, color: AppTheme.primary),
                    label: Text(
                      topic,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
              Icon(Icons.track_changes_rounded, size: 16, color: AppTheme.primary),
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
                final clean = e.length > 50 ? '${e.substring(0, 48)}...' : e;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
    );
  }
}
