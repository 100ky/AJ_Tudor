import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/data_providers.dart';
import '../../../data/database/app_database.dart';
import 'settings_common.dart';

/// Co si tutor pamatuje, úroveň angličtiny, počet lekcí a reset paměti.
class ProfileSummaryCard extends ConsumerWidget {
  final UserProfile profile;

  const ProfileSummaryCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SettingsIcon(Icons.psychology, AppTheme.primary),
            title: Text('Co si Tudor pamatuje',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor(context))),
            subtitle: Text(
              profile.memoryBriefing ?? 'Žádný briefing zatím není k dispozici.',
              style: GoogleFonts.plusJakartaSans(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SettingsIcon(Icons.school, AppTheme.success),
            title: Text('Úroveň angličtiny',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textColor(context))),
            trailing: DropdownButton<String>(
              value: ['A1', 'A2', 'B1', 'B2'].contains(profile.targetLevel)
                  ? profile.targetLevel
                  : 'B1',
              underline: const SizedBox(),
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontSize: 16),
              onChanged: (String? newLevel) async {
                if (newLevel != null) {
                  await ref.read(profileRepositoryProvider).updateTargetLevel(newLevel);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Úroveň angličtiny byla změněna na $newLevel! 🎯')),
                    );
                  }
                }
              },
              items: const [
                DropdownMenuItem(value: 'A1', child: Text('A1')),
                DropdownMenuItem(value: 'A2', child: Text('A2')),
                DropdownMenuItem(value: 'B1', child: Text('B1')),
                DropdownMenuItem(value: 'B2', child: Text('B2')),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SettingsIcon(Icons.history, AppTheme.accent),
            title: Text('Počet absolvovaných lekcí',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textColor(context))),
            trailing: Text(
              profile.totalSessions.toString(),
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.primary),
            ),
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          TextButton.icon(
            onPressed: () => _showResetDialog(context, ref),
            icon: Icon(Icons.delete_forever, color: AppTheme.error, size: 18),
            label: Text('Resetovat paměť a pokrok',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.error, fontSize: 13)),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resetovat paměť?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor(context),
            )),
        content: Text(
            'Tato akce vymaže vše, co si AI pamatuje o vašem pokroku. Nelze vrátit zpět.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.surfaceTextColor(context),
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zrušit',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.mutedTextColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(profileRepositoryProvider).resetUserMemory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paměť byla vymazána.')),
                );
              }
            },
            child: Text('Resetovat',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
