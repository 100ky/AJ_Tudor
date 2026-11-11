import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Živý přepis toho, co tutor právě říká, s blikajícím kurzorem.
class LiveTranscript extends StatelessWidget {
  final String transcript;

  /// Animace kurzoru (0.0–1.0, opakovaná tam a zpět).
  final Animation<double> cursor;

  const LiveTranscript({super.key, required this.transcript, required this.cursor});

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tudor', style: AppTheme.font(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textTertiary)),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: transcript),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AnimatedBuilder(
                  animation: cursor,
                  builder: (context, _) => Container(
                    width: 2,
                    height: 20,
                    margin: const EdgeInsets.only(left: 3),
                    color: AppTheme.textPrimary.withValues(alpha: cursor.value),
                  ),
                ),
              ),
            ]),
            style: AppTheme.font(fontSize: 19, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
