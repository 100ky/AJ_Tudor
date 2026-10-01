import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../profile_settings_controller.dart';
import 'settings_common.dart';

/// Fakta „O mně“, která si Tudor pamatuje, s možností přidat a smazat.
class UserFactsList extends ConsumerWidget {
  final List<String> facts;

  const UserFactsList({super.key, required this.facts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionLabel('Fakta o mně (${facts.length})'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: () => _showAddFactDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Přidat fakt'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (facts.isEmpty)
          GlassContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Zatím zde nejsou žádná fakta.\nTudor si automaticky ukládá informace z konverzací, nebo je můžete přidat ručně tlačítkem výše.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context),
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...facts.map((fact) => _FactTile(fact)),
      ],
    );
  }

  void _showAddFactDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondaryColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Přidat informaci o mně',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppTheme.textColor(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zadej fakt, který by si měl Tudor pamatovat (např. o zálibách, mazlíčcích, práci nebo životě):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Např. Mám psa labradora jménem Rex',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceMuted,
                ),
                filled: true,
                fillColor: AppTheme.glassLightColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.glassBorderColor(context)),
                ),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Zrušit',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.mutedTextColor(context)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogCtx);
                await ref.read(profileSettingsControllerProvider).addFact(text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informace byla úspěšně přidána! ✅')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Uložit',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends ConsumerWidget {
  final String fact;

  const _FactTile(this.fact);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.glassColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fact,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.onSurfaceMuted),
            visualDensity: VisualDensity.compact,
            tooltip: 'Smazat fakt',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await ref.read(profileSettingsControllerProvider).removeFact(fact);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fakt byl odstraněn z paměti.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
