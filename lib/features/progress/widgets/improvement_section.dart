import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/czech_plural.dart';
import '../../../core/widgets/grouped_section.dart';
import '../../../core/widgets/sparkline.dart';
import '../../../data/models/skill_profile.dart';

/// Co se zlepšuje: úroveň a ukazatele poslední lekce s grafem posledních lekcí.
///
/// Všechny ukazatele jsou otočené tak, že víc je líp (např. „83 slov na 1 chybu“ místo
/// „1,2 chyby na 100 slov“). Barva čáry a slovo za „dřív“ říkají, jestli se to zlepšilo.
class ImprovementSection extends StatelessWidget {
  final SkillProfile skills;

  const ImprovementSection({super.key, required this.skills});

  String _description() {
    final lessons = skills.history.length;
    final earlier = lessons - 1;
    if (earlier == 0) {
      return 'Zatím je tu jedna lekce. Srovnání s dřívějšími přibude po další lekci.';
    }
    final before = earlier == 1 ? 'lekce před poslední' : 'průměr $earlier lekcí před poslední';
    return 'Graf ukazuje posledních $lessons lekcí, nejnovější je vpravo. U všech ukazatelů platí, '
        'že výš je líp. Čárkovaná čára je „dřív“, $before.';
  }

  @override
  Widget build(BuildContext context) {
    final last = skills.last!;
    final previous = skills.previous;
    final lesson = skills.lastLesson!;
    final level = lesson.levelDetail ?? lesson.estimatedLevel;
    final history = skills.history;

    final rows = <Widget>[
      _MetricRow(
        name: 'Gramatika',
        value: _Reading(last.wordsPerGrammarError),
        unit: 'slov na 1 chybu',
        noneUnit: 'v gramatice',
        previous: previous == null ? null : _Reading(previous.wordsPerGrammarError),
        change: skills.grammarChange,
        series: [for (final s in history) s.wordsPerGrammarError],
      ),
      _MetricRow(
        name: 'Slovní zásoba',
        value: _Reading(last.wordsPerVocabularyError),
        unit: 'slov na 1 české nebo špatně zvolené slovo',
        noneUnit: 'české ani špatně zvolené slovo',
        noneText: 'žádné',
        previous: previous == null ? null : _Reading(previous.wordsPerVocabularyError),
        change: skills.vocabularyChange,
        series: [for (final s in history) s.wordsPerVocabularyError],
      ),
      if (last.wordsPerReply != null)
        _MetricRow(
          name: 'Délka odpovědí',
          value: _Reading(last.wordsPerReply),
          unit: 'slov v jedné odpovědi',
          previous: previous?.wordsPerReply == null ? null : _Reading(previous!.wordsPerReply),
          change: skills.repliesChange,
          series: [for (final s in history) ?s.wordsPerReply],
        ),
      _MetricRow(
        name: 'Kolik mluvíš ty',
        value: _Reading(last.share * 100),
        unit: 'slov z hovoru',
        percent: true,
        previous: previous == null ? null : _Reading(previous.share * 100),
        change: skills.shareChange,
        extra: 'cíl 50 %',
        series: [for (final s in history) s.share * 100],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Co se zlepšuje', description: _description()),
        if (level != null) ...[
          GroupedSection(children: [_LevelRow(level: level, reason: lesson.levelReason)]),
          const SizedBox(height: 10),
        ],
        GroupedSection(children: rows),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Lekce, ve kterých máš méně než ${SkillProfile.minStudentWords} slov, se nepočítají.',
            style: AppTheme.font(fontSize: 12.5, color: AppTheme.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Hodnota ukazatele; null znamená „bez chyby“ (u ukazatelů slov na chybu).
class _Reading {
  final double? value;
  const _Reading(this.value);
}

class _LevelRow extends StatelessWidget {
  final String level;
  final String? reason;

  const _LevelRow({required this.level, this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Úroveň v poslední lekci',
                    style: AppTheme.font(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              ),
              Text(level, style: AppTheme.font(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason!, style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String name;
  final _Reading value;

  /// Jednotka za číslem.
  final String unit;

  /// Text místo čísla a jednotka, když chyba nebyla (hodnota null).
  final String noneText;
  final String? noneUnit;

  final _Reading? previous;
  final SkillChange? change;

  /// Poznámka za hodnocením (např. „cíl 50 %“).
  final String? extra;

  /// Hodnoty od nejstarší lekce; null = v lekci bez chyby.
  final List<double?> series;

  final bool percent;

  const _MetricRow({
    required this.name,
    required this.value,
    required this.unit,
    required this.series,
    this.noneText = 'bez chyby',
    this.noneUnit,
    this.previous,
    this.change,
    this.extra,
    this.percent = false,
  });

  String _format(double v) => percent ? '${v.round()} %' : czechNumber(v);

  /// Lekce bez chyby se v grafu kreslí nad nejlepší ostatní lekcí.
  List<double> _chartValues() {
    final finite = series.whereType<double>();
    final top = finite.isEmpty ? 100.0 : finite.reduce((a, b) => a > b ? a : b) * 1.25;
    return [for (final v in series) v ?? top];
  }

  double? _chartReference(List<double> chart) {
    if (previous == null) return null;
    if (previous!.value != null) return previous!.value;
    return chart.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final (verdict, color) = switch (change) {
      SkillChange.better => ('lepší', AppTheme.success),
      SkillChange.worse => ('horší', AppTheme.error),
      SkillChange.same => ('stejně', AppTheme.textSecondary),
      null => (null, AppTheme.textSecondary),
    };
    final hasValue = value.value != null;
    final chart = _chartValues();
    final previousText = previous == null
        ? null
        : 'Dřív ${previous!.value == null ? noneText : _format(previous!.value!)}';

    final bottom = <InlineSpan>[
      if (previousText != null) TextSpan(text: previousText),
      if (verdict != null) ...[
        const TextSpan(text: ' · '),
        TextSpan(text: verdict, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
      if (extra != null) TextSpan(text: '${previousText != null ? ' · ' : ''}$extra'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.font(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: hasValue ? _format(value.value!) : noneText,
                      style: AppTheme.font(
                        fontSize: hasValue ? 28 : 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                    TextSpan(text: '  ${hasValue ? unit : (noneUnit ?? unit)}'),
                  ]),
                  style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.25),
                ),
                if (bottom.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: bottom),
                    style: AppTheme.font(fontSize: 13.5, color: AppTheme.textSecondary, fontFeatures: AppTheme.tabularFigures),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Sparkline(
            values: chart,
            reference: _chartReference(chart),
            color: color,
            semanticsLabel: '$name v posledních ${chart.length} '
                '${czechPlural(chart.length, 'lekci', 'lekcích', 'lekcích')}',
          ),
        ],
      ),
    );
  }
}
