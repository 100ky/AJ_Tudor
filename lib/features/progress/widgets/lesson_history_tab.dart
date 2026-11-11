import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../history/widgets/session_list.dart';

/// Záložka „Historie lekcí“ v Pokroku.
class LessonHistoryTab extends StatelessWidget {
  final List<Session> sessions;

  const LessonHistoryTab({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 36, color: AppTheme.textTertiary),
              const SizedBox(height: 14),
              Text(
                'Zatím nemáš žádné lekce',
                style: AppTheme.font(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'První lekci začneš tlačítkem Hovor uprostřed dole.',
                textAlign: TextAlign.center,
                style: AppTheme.font(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return SessionList(sessions: sessions);
  }
}
