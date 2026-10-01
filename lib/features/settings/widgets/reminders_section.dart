import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/widgets/glass_container.dart';

/// Denní připomínky: zapnutí, čas a „otravný režim“.
class RemindersSection extends ConsumerWidget {
  const RemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersEnabled = ref.watch(remindersEnabledProvider);

    return GlassContainer(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Denní připomínky',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor(context))),
            subtitle: Text('AI se připomene, když zapomenete trénovat.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppTheme.mutedTextColor(context))),
            value: remindersEnabled,
            onChanged: (value) {
              ref.read(remindersEnabledProvider.notifier).toggle(value);
            },
          ),
          if (remindersEnabled) ...[
            Divider(color: AppTheme.outlineLightColor(context)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Čas upozornění',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textColor(context))),
              trailing: Text(
                ref.watch(reminderTimeProvider),
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.primary),
              ),
              onTap: () => _pickTime(context, ref),
            ),
            Divider(color: AppTheme.outlineLightColor(context)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Otravný režim 😈',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textColor(context))),
              subtitle: Text('Více upozornění během dne. Nenechá vás v klidu.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: AppTheme.mutedTextColor(context))),
              value: ref.watch(annoyingModeProvider),
              onChanged: (value) {
                ref.read(annoyingModeProvider.notifier).toggle(value);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final timeStr = ref.read(reminderTimeProvider);
    final timeParts = timeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref.read(reminderTimeProvider.notifier).saveTime(formattedTime);
    }
  }
}
