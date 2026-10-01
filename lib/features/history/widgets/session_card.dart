import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/data_providers.dart';
import '../../../data/database/app_database.dart';
import 'delete_session_dialog.dart';
import 'session_detail_sheet.dart';

/// Karta jedné lekce v historii (datum, délka, plynulost, počet chyb).
/// Klepnutí otevře detail s přepisem.
class SessionCard extends ConsumerWidget {
  final Session session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('d. MMMM yyyy, HH:mm', 'cs');
    final dateStr = dateFormat.format(session.startedAt);

    String? durationStr;
    if (session.endedAt != null) {
      final diff = session.endedAt!.difference(session.startedAt);
      final minutes = diff.inMinutes;
      final seconds = diff.inSeconds.remainder(60);
      durationStr = minutes > 0 ? '$minutes min' : '$seconds s';
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showSessionDetail(context, ref),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          dateStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (durationStr != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 11,
                                  color: AppTheme.mutedTextColor(context)),
                              const SizedBox(width: 3),
                              Text(
                                durationStr,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.mutedTextColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (session.fluencyScore != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.success.withValues(alpha: 0.12),
                          AppTheme.successLight.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${(session.fluencyScore! * 100).toInt()}% plynulost',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.mutedTextColor(context),
                  ),
                  tooltip: 'Smazat lekci',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => confirmAndDeleteSession(context, ref, session),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.topicSummary ?? 'Lekce angličtiny',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (session.totalErrors == 0) ...[
                  Icon(Icons.check_circle_outline_rounded,
                      size: 15, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Text('Bez chyb 🎉',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ] else ...[
                  Icon(Icons.error_outline, size: 15, color: AppTheme.error),
                  const SizedBox(width: 4),
                  Text('${session.totalErrors} chyb',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.mutedTextColor(context),
                          fontSize: 13)),
                ],
                const Spacer(),
                Text(
                  'Zobrazit přepis',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
              ],
            ),
          ],
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
