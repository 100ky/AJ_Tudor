import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/agents/topic_preparation_agent.dart';
import '../../core/constants/gemini_models.dart';
import '../../services/system/backup_service.dart';
import 'package:flutter/services.dart';
import '../agents/agents_screen.dart';
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

  Widget _buildSectionLabel(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedTextColor(context),
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
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── API Klíč ──────────────────────────────────────────────────────
          _buildSectionLabel('Konfigurace umělé inteligence', context),
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
                          color: AppTheme.textColor(context),
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
                          ? AppTheme.mutedTextColor(context)
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
                        color: AppTheme.mutedTextColor(context),
                      ),
                      hintText: 'AIzaSy...',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.mutedTextColor(context)),
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
                                color: AppTheme.mutedTextColor(context))),
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

          // ── Vzhled aplikace ───────────────────────────────────────────────
          _buildSectionLabel('Vzhled aplikace', context),
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
                      child: Icon(Icons.palette_outlined,
                          size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Barevný motiv',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          Text(
                            'Světlý, tmavý nebo podle systému',
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                        label: Text('Světlý'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                        label: Text('Tmavý'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.settings_brightness_outlined, size: 16),
                        label: Text('Systém'),
                      ),
                    ],
                    selected: {ref.watch(themeModeProvider)},
                    onSelectionChanged: (set) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(themeModeProvider.notifier)
                          .saveThemeMode(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Upozornění ────────────────────────────────────────────────────
          _buildSectionLabel('Upozornění a připomínky', context),
          GlassContainer(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Denní připomínky',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textColor(context))),
                  subtitle: Text(
                      'AI se připomene, když zapomenete trénovat.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppTheme.mutedTextColor(context))),
                  value: ref.watch(remindersEnabledProvider),
                  onChanged: (value) {
                    ref.read(remindersEnabledProvider.notifier).toggle(value);
                  },
                ),
                if (ref.watch(remindersEnabledProvider)) ...[
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
                  Divider(color: AppTheme.outlineLightColor(context)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Otravný režim 😈',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textColor(context))),
                    subtitle: Text(
                        'Více upozornění během dne. Nenechá vás v klidu.',
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
          ),

          const SizedBox(height: 24),

          // ── Hlasové a konverzační nastavení ──────────────────────────────
          _buildSectionLabel('Hlasové a konverzační nastavení', context),
          GlassContainer(
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
                          color: AppTheme.textColor(context))),
                  subtitle: Text('Gemini Live Voice',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.mutedTextColor(context))),
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
          _buildSectionLabel('AI Model (Textový chat)', context),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Hlasový mód používá automaticky model optimalizovaný pro zvuk.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.mutedTextColor(context),
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
                    color: AppTheme.textColor(context), fontSize: 14),
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

          // ── Profil a paměť tutora ────────────────────────────────────────
          _buildSectionLabel('Můj profil a paměť tutora', context),
          Consumer(
            builder: (context, ref, child) {
              final profileAsync = ref.watch(userProfileProvider);
              final topicState = ref.watch(topicPreparationAgentProvider);

              return profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return GlassContainer(
                      child: Text('Zatím neproběhla žádná lekce.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.mutedTextColor(context))),
                    );
                  }

                  List<String> facts = [];
                  if (profile.userFacts.isNotEmpty) {
                    try {
                      final List<dynamic> raw = jsonDecode(profile.userFacts);
                      facts = raw.map((e) => e.toString()).toList();
                    } catch (_) {}
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                child: Icon(Icons.psychology,
                                    color: AppTheme.primary, size: 20),
                              ),
                              title: Text('Co si Tudor pamatuje',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textColor(context))),
                              subtitle: Text(
                                profile.memoryBriefing ??
                                    'Žádný briefing zatím není k dispozici.',
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
                                      color: AppTheme.textColor(context))),
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
                      ),

                      const SizedBox(height: 16),

                      // ── Karta: Připravené téma do hlasu ─────────────────────────
                      _buildSectionLabel('Připravené téma do hlasu', context),
                      _buildPreparedTopicCard(context, topicState),

                      const SizedBox(height: 16),

                      // ── Fakta o mně ─────────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionLabel('Fakta o mně (${facts.length})', context),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextButton.icon(
                              onPressed: () => _showAddFactDialog(context),
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
                        ...facts.map((fact) => _buildFactTile(context, fact)),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Chyba načítání profilu: $e'),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── AI Agenti ─────────────────────────────────────────────────────
          _buildSectionLabel('Multi-agentní systém', context),
          GlassContainer(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.smart_toy_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              title: Text('Správa a přehled AI agentů',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context))),
              subtitle: Text(
                  'Tutor, Analytik skóre a Plánovač témat na míru',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppTheme.mutedTextColor(context))),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgentsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Záloha ────────────────────────────────────────────────────────
          _buildSectionLabel('Zálohování a obnova dat', context),
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
                          color: AppTheme.textColor(context))),
                  subtitle: Text(
                      'Exportuje váš pokrok do souboru.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.mutedTextColor(context))),
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
                Divider(color: AppTheme.outlineLightColor(context)),
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
                          color: AppTheme.textColor(context))),
                  subtitle: Text(
                      'Načte data ze záložního souboru.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: AppTheme.mutedTextColor(context))),
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
                                    color: AppTheme.mutedTextColor(context))),
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
                                          color: AppTheme.textColor(context))),
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
                                  : 'Obnova dat se nezdařil. ❌')),
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
          _buildSectionLabel('Informace o aplikaci', context),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.mutedTextColor(context), size: 20),
                const SizedBox(width: 12),
                Text('Verze',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textColor(context))),
                const Spacer(),
                Text('0.1.0 - Dev Preview',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.mutedTextColor(context), fontSize: 13)),
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

  Widget _buildPreparedTopicCard(
      BuildContext context, TopicPreparationState topicState) {
    if (topicState.isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Tudor připravuje nové originální téma z historie...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final topic = topicState.topic;
    if (topic == null) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppTheme.onSurfaceMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Zatím není připraveno žádné téma.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.mutedTextColor(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Připravit téma',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                ref
                    .read(topicPreparationAgentProvider.notifier)
                    .prepareTopic(force: true);
              },
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primary.withValues(alpha: 0.05),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  topic.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Vyměnit téma',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: AppTheme.primary,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(topicPreparationAgentProvider.notifier)
                      .prepareTopic(force: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondaryColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.openerEn,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textColor(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (topic.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              topic.rationale,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppTheme.mutedTextColor(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactTile(BuildContext context, String fact) {
    final repo = ref.read(sessionRepositoryProvider);

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
            icon: Icon(Icons.close_rounded,
                size: 16, color: AppTheme.onSurfaceMuted),
            visualDensity: VisualDensity.compact,
            tooltip: 'Smazat fakt',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await repo.removeUserFact(fact);
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

  void _showAddFactDialog(BuildContext context) {
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
                  borderSide:
                      BorderSide(color: AppTheme.glassBorderColor(context)),
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
              style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedTextColor(context)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogCtx);
                await ref.read(sessionRepositoryProvider).addUserFact(text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Informace byla úspěšně přidána! ✅')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
