import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/database/app_database.dart';
import 'collapsible_card.dart';

/// Posledních 5 zaznamenaných chyb s vysvětlením.
class RecentErrorsCard extends StatelessWidget {
  final List<ErrorLog> errors;
  final bool expanded;
  final VoidCallback onToggle;

  /// Přepne přehled na záložku Historie lekcí.
  final VoidCallback onShowHistory;

  const RecentErrorsCard({
    super.key,
    required this.errors,
    required this.expanded,
    required this.onToggle,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleCard(
      title: 'Nedávné chyby',
      trailing: [
        if (errors.isNotEmpty) ...[
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onShowHistory();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Historie',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        CardBadge('${errors.length}'),
      ],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        if (errors.isEmpty)
          const EmptyStateCard('Zatím nemáš žádné zaznamenané chyby. Skvělá práce!')
        else
          ...errors.take(5).map((error) => _ErrorTile(error)),
      ],
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final ErrorLog error;

  const _ErrorTile(this.error);

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.errorTypeColor(error.errorType);
    final icon = AppTheme.errorTypeIcon(error.errorType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: color,
            collapsedIconColor: AppTheme.mutedTextColor(context),
            leading: Icon(icon, color: color, size: 20),
            title: Text(
              error.userSaid,
              style: GoogleFonts.hankenGrotesk(
                decoration: TextDecoration.lineThrough,
                color: AppTheme.error,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              error.correctForm,
              style: GoogleFonts.hankenGrotesk(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error.explanation,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: AppTheme.surfaceTextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
