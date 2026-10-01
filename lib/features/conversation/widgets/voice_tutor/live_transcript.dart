import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';

/// Živý přepis toho, co tutor právě říká, s blikajícím kurzorem.
class LiveTranscript extends StatelessWidget {
  final String transcript;

  /// Animace kurzoru (0.0–1.0, opakovaná tam a zpět).
  final Animation<double> cursor;

  const LiveTranscript({super.key, required this.transcript, required this.cursor});

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        color: AppTheme.speaking.withValues(alpha: 0.06),
        border: Border.all(color: AppTheme.speaking.withValues(alpha: 0.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Blikající kurzor
                AnimatedBuilder(
                  animation: cursor,
                  builder: (context, _) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.speaking.withValues(alpha: cursor.value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TUTOR SPEAKS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.speaking.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transcript,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textColor(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
