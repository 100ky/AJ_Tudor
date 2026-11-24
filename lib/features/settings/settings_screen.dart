import 'package:flutter/material.dart';
import '../../core/widgets/grouped_section.dart';
import '../../core/widgets/pill_tabs.dart';
import 'widgets/api_key_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/chat_model_section.dart';
import 'widgets/conversation_settings_section.dart';
import 'widgets/info_tiles.dart';
import 'widgets/profile_memory_section.dart';
import 'widgets/reminders_section.dart';
import 'widgets/settings_common.dart';

/// Profil a nastavení aplikace: přepínání mezi nastavením a pamětí tutora.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('Profil'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: PillTabs(
                labels: const ['Nastavení', 'Můj profil'],
                selected: _selectedTab,
                onChanged: (index) => setState(() => _selectedTab = index),
              ),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: const [
                        SectionLabel('Konfigurace umělé inteligence'),
                        ApiKeySection(),
                        SizedBox(height: 24),
                        SectionLabel('Upozornění a připomínky'),
                        RemindersSection(),
                        SizedBox(height: 24),
                        SectionLabel('Hlasové a konverzační nastavení'),
                        ConversationSettingsSection(),
                        SizedBox(height: 24),
                        SectionLabel('AI Model (Textový chat)'),
                        ChatModelSection(),
                        SizedBox(height: 24),
                        SectionLabel('Zálohování a obnova dat'),
                        BackupSection(),
                        SizedBox(height: 24),
                        SectionLabel('Informace o aplikaci'),
                        AppInfoCard(),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: const [
                        SectionLabel('Můj profil a paměť tutora'),
                        ProfileMemorySection(),
                        SizedBox(height: 24),
                        SectionLabel('Multi-agentní systém'),
                        AgentsLinkTile(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
