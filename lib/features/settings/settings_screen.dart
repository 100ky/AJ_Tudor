import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
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
            'AI Model (Textový chat)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}
