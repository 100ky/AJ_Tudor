import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/widgets/glass_container.dart';
import 'settings_common.dart';

/// Hlasové a konverzační nastavení: chytré bubliny, pohlcující režim,
/// hlas učitele a jeho trpělivost.
class ConversationSettingsSection extends ConsumerWidget {
  const ConversationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Chytré bubliny chatu',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textColor(context))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'NOVÉ ✨',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
                'Zobrazuje interaktivní opravy chyb, vysvětlení gramatiky, poslech výslovnosti a tlačítko pro uložení do kartiček.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppTheme.mutedTextColor(context))),
            value: ref.watch(smartBubblesEnabledProvider),
            onChanged: (value) {
              ref.read(smartBubblesEnabledProvider.notifier).toggle(value);
            },
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Pohlcující režim (Immersive Mode)',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor(context))),
            subtitle: Text(
                'Učitel bude mluvit 100% anglicky a nebude opravovat chyby nahlas.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppTheme.mutedTextColor(context))),
            value: ref.watch(immersiveModeProvider),
            onChanged: (value) {
              ref.read(immersiveModeProvider.notifier).toggle(value);
            },
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          _DropdownSetting<String>(
            icon: Icons.record_voice_over,
            color: AppTheme.speaking,
            title: 'Hlas učitele',
            subtitle: 'Gemini Live Voice',
            value: ref.watch(voiceProvider),
            onChanged: (String? newVoice) {
              if (newVoice != null) {
                ref.read(voiceProvider.notifier).saveVoice(newVoice);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hlas učitele změněn na: $newVoice 🗣️'),
                  ),
                );
              }
            },
            items: const [
              DropdownMenuItem(value: 'Puck', child: Text('Puck (Male)')),
              DropdownMenuItem(value: 'Charon', child: Text('Charon (Male)')),
              DropdownMenuItem(value: 'Kore', child: Text('Kore (Female)')),
              DropdownMenuItem(value: 'Fenrir', child: Text('Fenrir (Male)')),
              DropdownMenuItem(value: 'Aoede', child: Text('Aoede (Female)')),
            ],
          ),
          Divider(color: AppTheme.outlineLightColor(context)),
          _DropdownSetting<int>(
            icon: Icons.hourglass_top_rounded,
            color: AppTheme.primary,
            title: 'Trpělivost učitele (čas na rozmyšlenou)',
            subtitle: 'Jak dlouho AI čeká v tichu, než odpoví',
            value: ref.watch(speechPatienceProvider),
            onChanged: (int? newPatience) {
              if (newPatience != null) {
                ref.read(speechPatienceProvider.notifier).savePatience(newPatience);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Doba čekání na odpověď nastavena na: $newPatience ms ⏱️'),
                  ),
                );
              }
            },
            items: const [
              DropdownMenuItem(value: 800, child: Text('Rychlá (800 ms)')),
              DropdownMenuItem(value: 1200, child: Text('Přirozená (1 200 ms)')),
              DropdownMenuItem(value: 1500, child: Text('Trpělivá (1 500 ms)')),
              DropdownMenuItem(value: 2000, child: Text('Extra trpělivá (2 000 ms)')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nastavení s ikonou, popisem a rozbalovacím seznamem pod ním.
class _DropdownSetting<T> extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final T value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;

  const _DropdownSetting({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIcon(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.glassLightColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.outlineLightColor(context),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.mutedTextColor(context)),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontSize: 14,
                ),
                dropdownColor: AppTheme.isDark(context)
                    ? AppTheme.backgroundSecondaryDark
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                onChanged: onChanged,
                items: items,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
