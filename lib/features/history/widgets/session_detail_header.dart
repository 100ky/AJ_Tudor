import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';

/// Rozbalovací hlavička detailu lekce s akcemi (analýza, kartičky z chyb, smazání).
class SessionDetailHeader extends StatelessWidget {
  final Session session;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isAnalyzing;
  final bool isGeneratingCards;
  final VoidCallback onAnalyze;
  final VoidCallback onGenerateCards;
  final VoidCallback onDelete;

  const SessionDetailHeader({
    super.key,
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.isAnalyzing,
    required this.isGeneratingCards,
    required this.onAnalyze,
    required this.onGenerateCards,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.topicSummary ?? 'Detail lekce',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                    maxLines: expanded ? null : 1,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                  ),
                ),
                if (!expanded && session.fluencyScore != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(session.fluencyScore! * 100).toInt()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: AppTheme.error,
                  ),
                  tooltip: 'Smazat lekci',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppTheme.mutedTextColor(context),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: AppTheme.outlineLightColor(context),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (session.topicSummary == null ||
                        session.fluencyScore == null)
                      isAnalyzing
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : TextButton.icon(
                              icon: Icon(Icons.analytics_outlined,
                                  size: 15, color: AppTheme.primary),
                              label: const Text('Analyzovat'),
                              style: _actionStyle(),
                              onPressed: onAnalyze,
                            ),
                    TextButton.icon(
                      icon: isGeneratingCards
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 14),
                      label: const Text('Kartičky z chyb'),
                      style: _actionStyle(),
                      onPressed: isGeneratingCards ? null : onGenerateCards,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _actionStyle() {
    return TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: AppTheme.primary,
      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
    );
  }
}
