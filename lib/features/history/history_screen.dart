import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../data/data_providers.dart';
import 'widgets/session_list.dart';

/// Samostatný seznam proběhlých lekcí (v aplikaci je stejný seznam v Pokroku).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Historie konverzací')),
      body: Builder(
        builder: (context) {
          if (sessionsAsync.isLoading && !sessionsAsync.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = sessionsAsync.value ?? [];
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 36, color: AppTheme.textTertiary),
                  const SizedBox(height: 14),
                  Text(
                    'Zatím nemáš žádné lekce.',
                    style: AppTheme.font(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return SessionList(sessions: sessions);
        },
      ),
    );
  }
}
