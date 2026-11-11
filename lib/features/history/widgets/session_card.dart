import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
import '../../../data/data_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/progress_trends.dart';
import 'delete_session_dialog.dart';
import 'session_detail_header.dart';
import 'session_detail_sheet.dart';

/// Řádek jedné lekce v historii: čas, téma a délka, chyby, plynulost.
/// Klepnutí otevře detail s přepisem, podržení nabídne smazání.
class SessionCard extends ConsumerWidget {
  final Session session;

  const SessionCard({super.key, required this.session});

  /// Délka, chyby a plynulost; u krátké nebo nerozebrané lekce proč se nepočítá.
  static ({String text, bool warning}) meta(Session session) {
    final parts = <String>[];
    if (session.endedAt != null) {
      final diff = session.endedAt!.difference(session.startedAt);
      parts.add(diff.inMinutes > 0 ? '${diff.inMinutes} min' : '${diff.inSeconds.remainder(60)} s');
    }
    final tooShort = ProgressTrends.isCategorized(session) && session.studentWords! < ProgressTrends.minStudentWords;
    if (tooShort) return (text: [...parts, 'do pokroku se nepočítá'].join(' · '), warning: true);
    if (!SessionDetailHeader.isAnalyzed(session)) return (text: [...parts, 'rozbor zatím není'].join(' · '), warning: true);

    final errors = session.totalErrors;
    parts.add(errors == 0 ? 'bez chyb' : '$errors ${czechPlural(errors, 'chyba', 'chyby', 'chyb')}');
    if (session.fluencyScore != null) parts.add('plynulost ${(session.fluencyScore! * 100).round()} %');
    return (text: parts.join(' · '), warning: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = meta(session);
    return InkWell(
      onTap: () => _showSessionDetail(context, ref),
      onLongPress: () => confirmAndDeleteSession(context, ref, session),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 66),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  DateFormat('H:mm', 'cs').format(session.startedAt),
                  style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, fontFeatures: AppTheme.tabularFigures),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.topicSummary ?? 'Lekce angličtiny',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.font(fontSize: 15.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.text,
                      style: AppTheme.font(
                        fontSize: 13,
                        color: info.warning ? AppTheme.warning : AppTheme.textSecondary,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetail(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sessionRepositoryProvider);
    final transcripts = await repo.getTranscripts(session.id);
    final errors = await repo.getErrorLogs(session.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionDetailSheet(
        session: session,
        transcripts: transcripts,
        errors: errors,
      ),
    );
  }
}
