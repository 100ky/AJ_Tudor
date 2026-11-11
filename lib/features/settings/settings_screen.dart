import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'widgets/api_key_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/chat_model_section.dart';
import 'widgets/conversation_settings_section.dart';
import 'widgets/info_tiles.dart';
import 'widgets/profile_memory_section.dart';
import 'widgets/reminders_section.dart';
import 'widgets/settings_common.dart';

/// Nastavení aplikace: API klíč, připomínky, hlas, model, profil a záloha.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 64,
        title: Text(
          'Nastavení',
          style: AppTheme.font(fontSize: 32, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, letterSpacing: -0.8),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
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
          SectionLabel('Můj profil a paměť tutora'),
          ProfileMemorySection(),
          SizedBox(height: 24),
          SectionLabel('Multi-agentní systém'),
          AgentsLinkTile(),
          SizedBox(height: 24),
          SectionLabel('Zálohování a obnova dat'),
          BackupSection(),
          SizedBox(height: 24),
          SectionLabel('Informace o aplikaci'),
          AppInfoCard(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}
