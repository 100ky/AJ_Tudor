import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            title: Text(
              'Chytré bubliny chatu',
              style: AppTheme.font(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Zobrazuje interaktivní opravy chyb, vysvětlení gramatiky, poslech výslovnosti a tlačítko pro uložení do kartiček.',
              style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary),
            ),
            value: ref.watch(smartBubblesEnabledProvider),
            onChanged: (value) {
              ref.read(smartBubblesEnabledProvider.notifier).toggle(value);
            },
          ),
          const Divider(color: AppTheme.hairline),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Pohlcující režim (Immersive Mode)',
              style: AppTheme.font(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Učitel bude mluvit 100% anglicky a nebude opravovat chyby nahlas.',
              style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary),
            ),
            value: ref.watch(immersiveModeProvider),
            onChanged: (value) {
              ref.read(immersiveModeProvider.notifier).toggle(value);
            },
          ),
          const Divider(color: AppTheme.hairline),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Souvislý hovor',
              style: AppTheme.font(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Po výpadku spojení tutor naváže přesně tam, kde hovor skončil. Když to server odmítne, hovor poběží jako dosud. Platí od příští lekce.',
              style: AppTheme.font(fontSize: 13, color: AppTheme.textSecondary),
            ),
            value: ref.watch(sessionContinuityProvider),
            onChanged: (value) {
              ref.read(sessionContinuityProvider.notifier).toggle(value);
            },
          ),
          const Divider(color: AppTheme.hairline),
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
                    content: Text('Hlas učitele změněn na: $newVoice'),
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
          const Divider(color: AppTheme.hairline),
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
                    content: Text('Doba čekání na odpověď nastavena na: $newPatience ms'),
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
          const Divider(color: AppTheme.hairline),
          _DropdownSetting<int>(
            icon: Icons.history_rounded,
            color: AppTheme.primary,
            title: 'Návrat k probranému tématu',
            subtitle: 'Nejdéle po kolika dnech se tutor vrátí k oblasti, o které jste mluvili',
            value: ref.watch(topicRestDaysProvider),
            onChanged: (int? days) {
              if (days != null) ref.read(topicRestDaysProvider.notifier).save(days);
            },
            items: [
              for (final days in TopicRestDaysNotifier.options)
                DropdownMenuItem(
                  value: days,
                  child: Text(days == TopicRestDaysNotifier.defaultDays ? '$days dní (výchozí)' : _daysLabel(days)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// „3 dny“, „5 dní“.
String _daysLabel(int days) => days >= 2 && days <= 4 ? '$days dny' : '$days dní';

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
                      style: AppTheme.font(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTheme.font(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                style: AppTheme.font(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                dropdownColor: AppTheme.surface,
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
