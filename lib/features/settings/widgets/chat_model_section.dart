import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/constants/gemini_models.dart';
import '../../../core/widgets/glass_container.dart';

/// Volba modelu pro textový chat (hlasový mód má vlastní model).
class ChatModelSection extends ConsumerWidget {
  const ChatModelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hlasový mód používá automaticky model optimalizovaný pro zvuk.',
            style: AppTheme.font(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: ref.watch(modelProvider),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                style: AppTheme.font(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                dropdownColor: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
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
                      SnackBar(content: Text('Změněn model na: ${GeminiModels.getLabel(value)}')),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
