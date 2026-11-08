import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../data/models/progress_trends.dart';
import '../../../data/models/skill_profile.dart';
import 'collapsible_card.dart';

/// Co se zlepšuje: chyby podle druhu v posledních lekcích proti lekcím předtím
/// a kolik student mluví.
class ProgressTrendCard extends StatelessWidget {
  final ProgressTrends trends;
  final SkillProfile skills;
  final bool expanded;
  final VoidCallback onToggle;

  const ProgressTrendCard({
    super.key,
    required this.trends,
    this.skills = const SkillProfile(),
    required this.expanded,
    required this.onToggle,
  });

  String _perLesson(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedTextColor(context);
    final textStyle = GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textColor(context));
    final noteStyle = GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted, height: 1.35);
    final hasPrevious = trends.categories.any((t) => t.previous != null);

    return CollapsibleCard(
      icon: Icons.trending_down_rounded,
      color: AppTheme.success,
      title: 'Co se zlepšuje',
      trailing: [
        if (trends.averageShare != null)
          CardBadge('Mluvíš ${(trends.averageShare! * 100).round()} %', color: AppTheme.success),
      ],
      expanded: expanded,
      onToggle: onToggle,
      children: [
        const SizedBox(height: 12),
        if (!skills.isEmpty) ...[
          _SkillSection(skills: skills),
          const SizedBox(height: 14),
        ],
        if (trends.averageShare != null) ...[
          Text(
            'Podíl tvé řeči: ${(trends.averageShare! * 100).round()} % slov v posledních lekcích, '
            'v poslední ${(trends.lastShare! * 100).round()} %. Cíl je aspoň polovina.',
            style: textStyle,
          ),
          const SizedBox(height: 12),
        ],
        if (trends.categories.isEmpty)
          Text('Chyby podle druhu se ukážou po další lekci s rozborem.', style: noteStyle)
        else ...[
          Text(
            hasPrevious
                ? 'Chyby na lekci: posledních ${ProgressTrends.window} lekcí proti ${ProgressTrends.window} předtím'
                : 'Chyby na lekci v posledních lekcích (srovnání přibude po dalších lekcích)',
            style: noteStyle,
          ),
          const SizedBox(height: 8),
          for (final trend in trends.categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(trend.category.label, style: textStyle)),
                  Text(_perLesson(trend.recent), style: textStyle.copyWith(fontWeight: FontWeight.w700)),
                  if (trend.previous != null) ...[
                    const SizedBox(width: 6),
                    Text('(${_perLesson(trend.previous!)})', style: noteStyle),
                    const SizedBox(width: 4),
                    Icon(
                      trend.improved
                          ? Icons.arrow_downward_rounded
                          : trend.worse
                              ? Icons.arrow_upward_rounded
                              : Icons.remove_rounded,
                      size: 14,
                      color: trend.improved
                          ? AppTheme.success
                          : trend.worse
                              ? AppTheme.error
                              : muted,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Profil dovedností z poslední lekce proti průměru lekcí předtím.
class _SkillSection extends StatelessWidget {
  final SkillProfile skills;

  const _SkillSection({required this.skills});

  String _number(double value, {int digits = 1}) => value.toStringAsFixed(digits).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedTextColor(context);
    final textStyle = GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textColor(context));
    final noteStyle = GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted, height: 1.35);
    final last = skills.last!;
    final previous = skills.previous;
    final lesson = skills.lastLesson!;
    final level = lesson.levelDetail ?? lesson.estimatedLevel;

    Widget row(String label, String value, {String? before, bool? better}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(label, style: textStyle)),
              Text(value, style: textStyle.copyWith(fontWeight: FontWeight.w700)),
              if (before != null) ...[
                const SizedBox(width: 6),
                Text('($before)', style: noteStyle),
                const SizedBox(width: 4),
                Icon(
                  // U chyb je lepší méně, u slov víc: šipka by mátla, proto zatržítko a vykřičník
                  better == null
                      ? Icons.remove_rounded
                      : better
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                  size: 14,
                  color: better == null ? muted : (better ? AppTheme.success : AppTheme.error),
                ),
              ],
            ],
          ),
        );

    // Zlepšení, zhoršení, nebo beze změny (null) s tolerancí [noise]
    bool? compare(double now, double? before, {required bool lowerIsBetter, required double noise}) {
      if (before == null || (now - before).abs() <= noise) return null;
      return lowerIsBetter ? now < before : now > before;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (level != null)
          Text(
            'Úroveň v poslední lekci: $level${lesson.levelReason == null ? '' : '. ${lesson.levelReason}'}',
            style: textStyle,
          ),
        const SizedBox(height: 8),
        Text(
          previous == null
              ? 'Poslední lekce (srovnání přibude po dalších lekcích)'
              : 'Poslední lekce (v závorce průměr ${SkillProfile.previousLessons} lekcí předtím)',
          style: noteStyle,
        ),
        const SizedBox(height: 6),
        row(
          'Gramatika: chyb na 100 slov',
          _number(last.grammarPer100),
          before: previous == null ? null : _number(previous.grammarPer100),
          better: compare(last.grammarPer100, previous?.grammarPer100, lowerIsBetter: true, noise: 0.5),
        ),
        row(
          'Slovní zásoba: česká a špatná slova na 100 slov',
          _number(last.vocabularyPer100),
          before: previous == null ? null : _number(previous.vocabularyPer100),
          better: compare(last.vocabularyPer100, previous?.vocabularyPer100, lowerIsBetter: true, noise: 0.5),
        ),
        if (last.wordsPerReply != null)
          row(
            'Slov na repliku',
            _number(last.wordsPerReply!, digits: 0),
            before: previous?.wordsPerReply == null ? null : _number(previous!.wordsPerReply!, digits: 0),
            better: compare(last.wordsPerReply!, previous?.wordsPerReply, lowerIsBetter: false, noise: 1),
          ),
        row(
          'Tvoje řeč',
          '${(last.share * 100).round()} %',
          before: previous == null ? null : '${(previous.share * 100).round()} %',
          better: compare(last.share, previous?.share, lowerIsBetter: false, noise: 0.05),
        ),
      ],
    );
  }
}
