import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/constants/gemini_models.dart';
import '../../../core/widgets/glass_container.dart';

/// Volba modelu pro textový chat (hlasový mód má vlastní model).
class ChatModelSection extends ConsumerWidget {
  const ChatModelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}
