import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE6100C22) : const Color(0xE6FFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.hankenGrotesk(
                color: AppTheme.textColor(context),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Napiš překlad nebo se zeptej na gramatiku...',
                hintStyle: GoogleFonts.hankenGrotesk(
                  color: AppTheme.mutedTextColor(context),
                  fontSize: 14,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLoading ? AppTheme.surfaceRaised : AppTheme.textPrimary,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: AppTheme.background,
                size: 20,
              ),
            ),
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
          shadows: AppTheme.glassShadowLight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              // Na úzkém displeji se text zalomí, místo aby přetekl
              Flexible(
                child: Text(
                  'Tutor vyhodnocuje a připravuje cvičení...',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: AppTheme.mutedTextColor(context),
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
