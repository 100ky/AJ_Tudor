import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';

/// Spodní lišta drilu pro psaní překladů a dotazů na gramatiku.
class DrillInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const DrillInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.navBar,
        border: Border(
          top: BorderSide(color: AppTheme.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTheme.font(
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Napiš překlad nebo se zeptej na gramatiku...',
                hintStyle: AppTheme.font(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            tooltip: 'Odeslat',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: AppTheme.background,
              disabledBackgroundColor: AppTheme.surfaceRaised,
              minimumSize: const Size(46, 46),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Bublina „tutor přemýšlí“ během čekání na odpověď.
class DrillThinkingBubble extends StatelessWidget {
  const DrillThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              // Na úzkém displeji se text zalomí, místo aby přetekl
              Flexible(
                child: Text(
                  'Tutor vyhodnocuje a připravuje cvičení...',
                  style: AppTheme.font(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
