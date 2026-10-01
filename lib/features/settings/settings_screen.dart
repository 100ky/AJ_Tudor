import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import 'widgets/api_key_section.dart';
import 'widgets/appearance_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/chat_model_section.dart';
import 'widgets/conversation_settings_section.dart';
import 'widgets/info_tiles.dart';
import 'widgets/profile_memory_section.dart';
import 'widgets/reminders_section.dart';
import 'widgets/settings_common.dart';

/// Nastavení aplikace: API klíč, vzhled, připomínky, hlas, model, profil a záloha.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        children: const [
          SectionLabel('Konfigurace umělé inteligence'),
          ApiKeySection(),
          SizedBox(height: 24),
          SectionLabel('Vzhled aplikace'),
          AppearanceSection(),
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
