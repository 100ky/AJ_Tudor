import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/constants/gemini_models.dart';


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

  @override
  Widget build(BuildContext context) {
    final currentKey = ref.watch(apiKeyProvider);
    final hasKey = currentKey != null && currentKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Konfigurace umělé inteligence',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Google Gemini API Klíč',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (hasKey && !_isEditing)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) ...[
                    Text(
                      hasKey ? 'Klíč je uložen a připraven k použití.' : 'Není nastaven žádný klíč. Aplikace nebude fungovat.',
                      style: TextStyle(color: hasKey ? Colors.grey[400] : Colors.red[300]),
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
                        icon: const Icon(Icons.edit),
                        label: Text(hasKey ? 'Změnit API klíč' : 'Vložit API klíč'),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'API Klíč',
                        hintText: 'AIzaSy...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
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
                          child: const Text('Zrušit'),
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
          ),
          const SizedBox(height: 24),
          const Text(
            'Upozornění a připomínky',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Denní připomínky'),
                  subtitle: const Text('AI se připomene, když zapomenete trénovat.'),
                  value: ref.watch(remindersEnabledProvider),
                  onChanged: (value) {
                    ref.read(remindersEnabledProvider.notifier).toggle(value);
                  },
                ),
                if (ref.watch(remindersEnabledProvider)) ...[
                  const Divider(),
                  ListTile(
                    title: const Text('Čas upozornění'),
                    trailing: Text(
                      ref.watch(reminderTimeProvider),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        ref.read(reminderTimeProvider.notifier).saveTime(formattedTime);
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Otravný režim 😈'),
                    subtitle: const Text('Více upozornění během dne. Nenechá vás v klidu.'),
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
          const Text(
            'Hlasové a výukové nastavení',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Pohlcující režim (Immersive Mode)'),
                  subtitle: const Text('Učitel bude mluvit 100% anglicky a nebude opravovat chyby nahlas.'),
                  value: ref.watch(immersiveModeProvider),
                  onChanged: (value) {
                    ref.read(immersiveModeProvider.notifier).toggle(value);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('Hlas učitele (Gemini Voice)'),
                  subtitle: const Text('Vyberte přednastavený hlas Gemini Live.'),
                  trailing: DropdownButton<String>(
                    value: ref.watch(voiceProvider),
                    underline: const SizedBox(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16),
                    onChanged: (String? newVoice) {
                      if (newVoice != null) {
                        ref.read(voiceProvider.notifier).saveVoice(newVoice);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hlas učitele změněn na: $newVoice 🗣️')),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI Model (Textový chat)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Text(
              'Hlasový mód používá automaticky model optimalizovaný pro zvuk (Gemini 2.5 Native Audio).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ref.watch(modelProvider),
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
          ),
          const SizedBox(height: 24),
          const Text(
            'Můj pokrok a paměť',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, child) {
              final profileAsync = ref.watch(userProfileProvider);
              return profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Zatím neproběhla žádná lekce.'),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.psychology),
                          title: const Text('Co si AI pamatuje (Briefing)'),
                          subtitle: Text(
                            profile.memoryBriefing ?? 'Žádný briefing zatím není k dispozici.',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        const Divider(),
                         ListTile(
                          leading: const Icon(Icons.school),
                          title: const Text('Úroveň angličtiny'),
                          subtitle: const Text('Změnit obtížnost konverzace s učitelem'),
                          trailing: DropdownButton<String>(
                            value: ['A1', 'A2', 'B1', 'B2'].contains(profile.targetLevel) ? profile.targetLevel : 'B1',
                            underline: const SizedBox(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16),
                            onChanged: (String? newLevel) async {
                              if (newLevel != null) {
                                await ref.read(sessionRepositoryProvider).updateTargetLevel(newLevel);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Úroveň angličtiny byla změněna na $newLevel! 🎯')),
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
                          leading: const Icon(Icons.history),
                          title: const Text('Počet absolvovaných lekcí'),
                          trailing: Text(profile.totalSessions.toString()),
                        ),
                        const Divider(),
                        TextButton.icon(
                          onPressed: () => _showResetDialog(context),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Resetovat paměť a pokrok', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Chyba načítání profilu: $e'),
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Informace o aplikaci',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Verze'),
            subtitle: const Text('0.1.0 - Dev Preview'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetovat paměť?'),
        content: const Text('Tato akce vymaže vše, co si AI pamatuje o vašem pokroku. Nelze vrátit zpět.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
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
            child: const Text('Resetovat', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
