import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/widgets/glass_container.dart';
import 'settings_common.dart';

/// Zobrazení a úprava Gemini API klíče.
class ApiKeySection extends ConsumerStatefulWidget {
  const ApiKeySection({super.key});

  @override
  ConsumerState<ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends ConsumerState<ApiKeySection>
    with AutomaticKeepAliveClientMixin {
  final _apiKeyController = TextEditingController();
  bool _isEditing = false;

  // Rozepsaný klíč nesmí zmizet, když sekce odroluje mimo obrazovku.
  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    final currentKey = ref.watch(apiKeyProvider);
    final hasKey = currentKey != null && currentKey.isNotEmpty;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIcon(Icons.vpn_key_outlined, AppTheme.primary),
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
                  child: Icon(Icons.check_rounded, color: AppTheme.success, size: 16),
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
                color: hasKey ? AppTheme.mutedTextColor(context) : AppTheme.error,
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
    );
  }
}
