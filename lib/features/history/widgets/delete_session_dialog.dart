import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../session_detail_controller.dart';

/// Zeptá se na potvrzení a smaže lekci z historie.
///
/// Po úspěšném smazání zavolá [onDeleted] a zobrazí potvrzení.
Future<void> confirmAndDeleteSession(
  BuildContext context,
  WidgetRef ref,
  Session session, {
  VoidCallback? onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Smazat lekci?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          )),
      content: Text(
          'Opravdu chceš smazat tuto lekci z historie? Tato akce je nevratná.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.surfaceTextColor(context),
          )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Zrušit',
              style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Smazat',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.error)),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final result = await ref.read(sessionDetailControllerProvider).deleteSession(session.id);

  if (!context.mounted) return;

  result.fold(
    (_) {
      onDeleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lekce byla smazána. Paměť a scénáře se aktualizují.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    (failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba: ${failure.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
  );
}
