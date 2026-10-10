import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../session_detail_controller.dart';

/// Zeptá se na popis problému, který se v lekci projevil, a uloží ho k lekci.
///
/// S [transcript] se problém váže ke konkrétní replice (podle jejího času se pak
/// dohledá místo v logu lekce).
Future<void> showReportIssueDialog(
  BuildContext context,
  WidgetRef ref,
  Session session, {
  Transcript? transcript,
}) async {
  final note = await showDialog<String>(
    context: context,
    builder: (context) => _ReportIssueDialog(transcript: transcript),
  );

  if (note == null || note.trim().isEmpty || !context.mounted) return;

  final result = await ref
      .read(sessionDetailControllerProvider)
      .reportIssue(session.id, note.trim(), transcript: transcript);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.isSuccess
          ? 'Problém uložen k lekci. Log lekce zůstane v telefonu k rozboru.'
          : 'Popis problému se nepodařilo uložit.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _ReportIssueDialog extends StatefulWidget {
  final Transcript? transcript;

  const _ReportIssueDialog({this.transcript});

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.transcript;

    return AlertDialog(
      title: Text('Nahlásit problém',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          )),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transcript != null) ...[
            Text(
              '${transcript.speaker == 'user' ? 'Ty' : 'Tudor'}: „${transcript.content}“',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Co se stalo? Např. „Tudor se zasekl a moji větu neuložil.“',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Zrušit',
              style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Uložit',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.primary)),
        ),
      ],
    );
  }
}
