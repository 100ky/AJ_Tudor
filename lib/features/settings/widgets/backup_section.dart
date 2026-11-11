import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../services/system/backup_service.dart';
import 'settings_common.dart';

/// Export a obnova zálohy databáze.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SettingsIcon(Icons.backup_outlined, AppTheme.primary),
            title: Text('Vytvořit zálohu pokroku',
                style: GoogleFonts.hankenGrotesk(
                    color: AppTheme.textColor(context))),
            subtitle: Text('Exportuje váš pokrok do souboru.',
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 12, color: AppTheme.mutedTextColor(context))),
            onTap: () async {
              final success = await ref.read(backupServiceProvider).exportBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(success
                          ? 'Záloha byla úspěšně exportována! 📤'
                          : 'Export zálohy se nezdařil. ❌')),
                );
              }
            },
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SettingsIcon(Icons.settings_backup_restore_outlined, AppTheme.warning),
            title: Text('Obnovit pokrok ze zálohy',
                style: GoogleFonts.hankenGrotesk(
                    color: AppTheme.textColor(context))),
            subtitle: Text('Načte data ze záložního souboru.',
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 12, color: AppTheme.mutedTextColor(context))),
            onTap: () => _restore(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Obnovit data?',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600)),
        content: Text(
            'Tato akce nahradí všechna stávající data vybranou zálohou. Nelze vrátit zpět.',
            style: GoogleFonts.hankenGrotesk()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Zrušit',
                style: GoogleFonts.hankenGrotesk(
                    color: AppTheme.mutedTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Obnovit',
                style: GoogleFonts.hankenGrotesk(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: GlassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                Text('Probíhá obnova dat...',
                    style: GoogleFonts.hankenGrotesk(
                        color: AppTheme.textColor(context))),
              ],
            ),
          ),
        ),
      );
    }

    final success = await ref.read(backupServiceProvider).importBackup();

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(success
                ? 'Data byla úspěšně obnovena! 🎉'
                : 'Obnova dat se nezdařil. ❌')),
      );
    }
  }
}
