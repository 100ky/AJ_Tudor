import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../../services/system/backup_service.dart';
import '../../core/app_theme.dart';
import '../../core/widgets/glass_container.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Initialize the text controller with the current key if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentKey = ref.read(apiKeyProvider);
      if (currentKey != null) {
        _apiKeyController.text = currentKey;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveKey() {
    final newKey = _apiKeyController.text.trim();
    if (newKey.isNotEmpty) {
      ref.read(apiKeyProvider.notifier).saveKey(newKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API klíč úspěšně uložen! ✅')),
      );
    } else {
      ref.read(apiKeyProvider.notifier).clearKey();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API klíč byl vymazán. ❌')),
      );
    }
    setState(() {
      _isEditing = false;
    });
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurfaceMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ref.watch(apiKeyProvider);
    final hasKey = currentKey != null && currentKey.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Nastavení',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.onBackground,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── API Klíč ──────────────────────────────────────────────────────
          _buildSectionLabel('Konfigurace umělé inteligence'),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.vpn_key_outlined,
                          size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Google Gemini API Klíč',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                      ),
                    ),
                    if (hasKey && !_isEditing)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded,
                            color: AppTheme.success, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isEditing) ...[
                  Text(
                    hasKey
                        ? 'Klíč je uložen a připraven k použití.'
                        : 'Není nastaven žádný klíč. Aplikace nebude fungovat.',
                    style: GoogleFonts.plusJakartaSans(
                      color: hasKey
                          ? AppTheme.onSurfaceMuted
                          : AppTheme.error,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(hasKey ? 'Změnit API klíč' : 'Vložit API klíč'),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Klíč',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurfaceMuted,
                      ),
                      hintText: 'AIzaSy...',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.onSurfaceMuted),
                        onPressed: () => _apiKeyController.clear(),
                      ),
                    ),
                    obscureText: true, // Skrýt klíč kvůli bezpečnosti
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _apiKeyController.text = currentKey ?? '';
                            _isEditing = false;
                          });
                        },
                        child: Text('Zrušit',
                            style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.onSurfaceMuted)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saveKey,
                        child: const Text('Uložit'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Upozornění ────────────────────────────────────────────────────
          _buildSectionLabel('Upozornění a připomínky'),
          GlassContainer(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Denní připomínky',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onBackground)),
                  subtitle: Text(
                      'AI se připomene, když zapomenete trénovat.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppTheme.onSurfaceMuted)),
                  value: ref.watch(remindersEnabledProvider),
                  onChanged: (value) {
                    ref.read(remindersEnabledProvider.notifier).toggle(value);
                  },
                ),
                if (ref.watch(remindersEnabledProvider)) ...[
                  Divider(color: AppTheme.outlineLight),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Čas upozornění',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.onBackground)),
                    trailing: Text(
                      ref.watch(reminderTimeProvider),
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.primary),
                    ),
                    onTap: () async {
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
                        ref
                            .read(reminderTimeProvider.notifier)
                            .saveTime(formattedTime);
                      }
                    },
                  ),
                  Divider(color: AppTheme.outlineLight),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Otravný režim 😈',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onBackground)),
                    subtitle: Text(
                        'Více upozornění během dne. Nenechá vás v klidu.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppTheme.onSurfaceMuted)),
                    value: ref.watch(annoyingModeProvider),
                    onChanged: (value) {
                      ref.read(annoyingModeProvider.notifier).toggle(value);
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Hlasové nastavení ──────────────────────────────────────────────
          _buildSectionLabel('Hlasové a výukové nastavení'),
          GlassContainer(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Pohlcující režim (Immersive Mode)',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onBackground)),
                  subtitle: Text(
                      'Učitel bude mluvit 100% anglicky a nebude opravovat chyby nahlas.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppTheme.onSurfaceMuted)),
                  value: ref.watch(immersiveModeProvider),
                  onChanged: (value) {
                    ref.read(immersiveModeProvider.notifier).toggle(value);
                  },
                ),
                Divider(color: AppTheme.outlineLight),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.speaking.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.record_voice_over,
                        color: AppTheme.speaking, size: 20),
                  ),
                  title: Text('Hlas učitele',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onBackground)),
                  subtitle: Text('Gemini Live Voice',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.onSurfaceMuted)),
                  trailing: DropdownButton<String>(
                    value: ref.watch(voiceProvider),
                    underline: const SizedBox(),
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        fontSize: 14),
                    onChanged: (String? newVoice) {
                      if (newVoice != null) {
                        ref.read(voiceProvider.notifier).saveVoice(newVoice);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Hlas učitele změněn na: $newVoice 🗣️')),
                        );
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'Puck', child: Text('Puck (Male)')),
                      DropdownMenuItem(
                          value: 'Charon', child: Text('Charon (Male)')),
                      DropdownMenuItem(
                          value: 'Kore', child: Text('Kore (Female)')),
                      DropdownMenuItem(
                          value: 'Fenrir', child: Text('Fenrir (Male)')),
                      DropdownMenuItem(
                          value: 'Aoede', child: Text('Aoede (Female)')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── AI Model ──────────────────────────────────────────────────────
          _buildSectionLabel('AI Model (Textový chat)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Hlasový mód používá automaticky model optimalizovaný pro zvuk.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: ref.watch(modelProvider),
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onBackground, fontSize: 14),
                items: GeminiModels.allowedChatModels.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(GeminiModels.getLabel(model)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(modelProvider.notifier).saveModel(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Změněn model na: $value')),
                    );
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Profil a paměť ────────────────────────────────────────────────
          _buildSectionLabel('Můj pokrok a paměť'),
          Consumer(
            builder: (context, ref, child) {
              final profileAsync = ref.watch(userProfileProvider);
              return profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return GlassContainer(
                      child: Text('Zatím neproběhla žádná lekce.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.onSurfaceMuted)),
                    );
                  }
                  return GlassContainer(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.psychology,
                                color: AppTheme.primary, size: 20),
                          ),
                          title: Text('Co si AI pamatuje',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.onBackground)),
                          subtitle: Text(
                            profile.memoryBriefing ??
                                'Žádný briefing zatím není k dispozici.',
                            style: GoogleFonts.plusJakartaSans(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: AppTheme.onSurfaceMuted,
                            ),
                          ),
                        ),
                        Divider(color: AppTheme.outlineLight),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.school,
                                color: AppTheme.success, size: 20),
                          ),
                          title: Text('Úroveň angličtiny',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.onBackground)),
                          trailing: DropdownButton<String>(
                            value: ['A1', 'A2', 'B1', 'B2']
                                    .contains(profile.targetLevel)
                                ? profile.targetLevel
                                : 'B1',
                            underline: const SizedBox(),
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                                fontSize: 16),
                            onChanged: (String? newLevel) async {
                              if (newLevel != null) {
                                await ref
                                    .read(sessionRepositoryProvider)
                                    .updateTargetLevel(newLevel);
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
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.history,
                                color: AppTheme.accent, size: 20),
                          ),
                          title: Text('Počet absolvovaných lekcí',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.onBackground)),
                          trailing: Text(
                            profile.totalSessions.toString(),
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.primary),
                          ),
                        ),
                        Divider(color: AppTheme.outlineLight),
                        TextButton.icon(
                          onPressed: () => _showResetDialog(context),
                          icon: Icon(Icons.delete_forever,
                              color: AppTheme.error, size: 18),
                          label: Text('Resetovat paměť a pokrok',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.error, fontSize: 13)),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Chyba načítání profilu: $e'),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Záloha ────────────────────────────────────────────────────────
          _buildSectionLabel('Zálohování a obnova dat'),
          GlassContainer(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.backup_outlined,
                        color: AppTheme.primary, size: 20),
                  ),
                  title: Text('Vytvořit zálohu pokroku',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onBackground)),
                  subtitle: Text(
                      'Exportuje váš pokrok do souboru.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.onSurfaceMuted)),
                  onTap: () async {
                    final success =
                        await ref.read(backupServiceProvider).exportBackup();
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
                Divider(color: AppTheme.outlineLight),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.settings_backup_restore_outlined,
                        color: AppTheme.warning, size: 20),
                  ),
                  title: Text('Obnovit pokrok ze zálohy',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onBackground)),
                  subtitle: Text(
                      'Načte data ze záložního souboru.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.onSurfaceMuted)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Obnovit data?',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600)),
                        content: Text(
                            'Tato akce nahradí všechna stávající data vybranou zálohou. Nelze vrátit zpět.',
                            style: GoogleFonts.plusJakartaSans()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Zrušit',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.onSurfaceMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Obnovit',
                                style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.error)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: GlassContainer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: AppTheme.primary),
                                  const SizedBox(height: 16),
                                  Text('Probíhá obnova dat...',
                                      style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.onBackground)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final success =
                          await ref.read(backupServiceProvider).importBackup();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(success
                                  ? 'Data byla úspěšně obnovena! 🎉'
                                  : 'Obnova dat se nezdařila. ❌')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Info ──────────────────────────────────────────────────────────
          _buildSectionLabel('Informace o aplikaci'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.onSurfaceMuted, size: 20),
                const SizedBox(width: 12),
                Text('Verze',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onBackground)),
                const Spacer(),
                Text('0.1.0 - Dev Preview',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.onSurfaceMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resetovat paměť?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        content: Text(
            'Tato akce vymaže vše, co si AI pamatuje o vašem pokroku. Nelze vrátit zpět.',
            style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zrušit',
                style:
                    GoogleFonts.plusJakartaSans(color: AppTheme.onSurfaceMuted)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sessionRepositoryProvider).resetUserMemory();
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
