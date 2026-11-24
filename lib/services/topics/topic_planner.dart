import 'dart:math';

import '../../data/models/topic_record.dart';
import 'topic_catalog.dart';

/// Oblast nabídnutá pro příští téma.
class TopicOffer {
  final TopicArea area;

  /// V oblasti jste ještě nemluvili.
  final bool isNew;

  /// Kdy se o oblasti mluvilo naposledy (null u nové).
  final DateTime? lastDiscussed;

  /// Co jste v oblasti probrali, od nejnovějšího (nejvýš tři).
  final List<String> recentTitles;

  /// Náměty z katalogu.
  final List<String> seeds;

  const TopicOffer({
    required this.area,
    required this.isNew,
    required this.lastDiscussed,
    required this.recentTitles,
    required this.seeds,
  });

  /// Řádek pro prompt: název, jestli je nová nebo k zopakování, a náměty.
  String describe(DateTime now) {
    final seedText = seeds.isEmpty ? '' : ' Náměty: ${seeds.join('; ')}.';
    if (isNew) return '${area.label}: NOVÁ oblast, ještě jste o ní nemluvili.$seedText';
    final days = now.difference(lastDiscussed!).inDays;
    final when = days <= 0 ? 'dnes' : (days == 1 ? 'včera' : 'před $days dny');
    final what = recentTitles.isEmpty ? '' : ' (${recentTitles.join('; ')})';
    return '${area.label}: k zopakování, naposledy $when$what. Naváž na to z nového úhlu.$seedText';
  }
}

/// Návrh pro příští hovor: nabídnuté oblasti a oblasti, které teď odpočívají.
class TopicPlan {
  /// Oblasti k výběru tématu, aspoň jedna nová (když nějaká zbývá).
  final List<TopicOffer> offers;

  /// Nedávno probrané oblasti (sám je tutor ani generátor neotevírá).
  final List<TopicArea> resting;

  /// Kdy byl návrh spočítán (pro „před N dny“ v promptu).
  final DateTime now;

  const TopicPlan({required this.offers, required this.resting, required this.now});

  /// Prázdný návrh (evidence se nepodařila načíst): prompty pak zůstanou bez nabídky.
  static final TopicPlan empty = TopicPlan(offers: const [], resting: const [], now: DateTime(2000));

  bool get isEmpty => offers.isEmpty && resting.isEmpty;

  /// Názvy nabídnutých oblastí (pro krátké pokyny v anglickém textu stačí české názvy).
  List<String> get offerLabels => [for (final o in offers) o.area.label];

  List<String> get restingLabels => [for (final a in resting) a.label];

  /// Nabídka pro prompt, každá oblast na řádku.
  String offersBlock() => [for (final (i, o) in offers.indexed) '${i + 1}. ${o.describe(now)}'].join('\n');
}

/// Plánuje oblasti témat podle evidence: o čem se nedávno mluvilo, odpočívá, a vrací se
/// s rostoucím odstupem (2, 4, 7 dní). Odstup nikdy nepřesáhne [maxRestDays]: po měsíci by
/// student zapomněl, o čem se mluvilo.
abstract final class TopicPlanner {
  /// Výchozí nejdelší odstup, po kterém se probraná oblast znovu nabídne.
  static const int defaultMaxRestDays = 7;

  /// Kolik oblastí se nabízí.
  static const int offerCount = 3;

  /// Odstup po [sessions] lekcích s oblastí: 2, 4, 8… dní, nejvýš [maxRestDays].
  static Duration restAfter(int sessions, {int maxRestDays = defaultMaxRestDays}) {
    if (sessions <= 0) return Duration.zero;
    final days = 2 << min(sessions - 1, 4);
    return Duration(days: min(days, max(1, maxRestDays)));
  }

  /// Návrh oblastí z evidence [records] k času [now].
  ///
  /// Nabídne [count] oblastí: jednu novou (náhodně z těch, o kterých jste nemluvili)
  /// a zbytek z oblastí, kterým odstup uplynul, nejdřív ty, které čekají nejdéle vzhledem
  /// ke svému odstupu. Když nové oblasti došly, místo nové přijde nejméně probraná.
  /// Oblasti v [exclude] se nenabízejí (např. téma, o kterém se právě mluví).
  static TopicPlan plan(
    List<TopicRecord> records, {
    required DateTime now,
    int maxRestDays = defaultMaxRestDays,
    int count = offerCount,
    Set<String> exclude = const {},
    Random? random,
  }) {
    final rng = random ?? Random();
    final sessionsByArea = <String, Set<int>>{};
    final lastByArea = <String, DateTime>{};
    final titlesByArea = <String, List<TopicRecord>>{};
    for (final record in records) {
      if (TopicCatalog.byId(record.areaId) == null) continue;
      sessionsByArea.putIfAbsent(record.areaId, () => {}).add(record.sessionId);
      final last = lastByArea[record.areaId];
      if (last == null || record.discussedAt.isAfter(last)) lastByArea[record.areaId] = record.discussedAt;
      titlesByArea.putIfAbsent(record.areaId, () => []).add(record);
    }

    final fresh = <TopicArea>[];
    final due = <(TopicArea, double)>[];
    final resting = <(TopicArea, DateTime)>[];
    for (final area in TopicCatalog.areas) {
      final sessions = sessionsByArea[area.id]?.length ?? 0;
      if (sessions == 0) {
        if (!exclude.contains(area.id)) fresh.add(area);
        continue;
      }
      final last = lastByArea[area.id]!;
      final rest = restAfter(sessions, maxRestDays: maxRestDays);
      final waited = now.difference(last);
      if (waited >= rest) {
        if (!exclude.contains(area.id)) due.add((area, waited.inMinutes / rest.inMinutes));
      } else {
        resting.add((area, last));
      }
    }
    due.sort((a, b) => b.$2.compareTo(a.$2));
    resting.sort((a, b) => b.$2.compareTo(a.$2));

    TopicOffer offer(TopicArea area) {
      final titles = [...?titlesByArea[area.id]]..sort((a, b) => b.discussedAt.compareTo(a.discussedAt));
      final seeds = [...area.seeds]..shuffle(rng);
      return TopicOffer(
        area: area,
        isNew: !sessionsByArea.containsKey(area.id),
        lastDiscussed: lastByArea[area.id],
        recentTitles: [
          for (final title in titles.map((t) => t.title).toSet().take(3)) title,
        ],
        seeds: seeds.take(3).toList(),
      );
    }

    final chosen = <TopicArea>[];
    // Jedna nová oblast; když žádná nezbývá, nejméně probraná z těch, kterým odstup uplynul
    if (fresh.isNotEmpty) {
      chosen.add(fresh[rng.nextInt(fresh.length)]);
    } else if (due.isNotEmpty) {
      final leastSessions = due.map((d) => sessionsByArea[d.$1.id]!.length).reduce(min);
      final least = due.where((d) => sessionsByArea[d.$1.id]!.length == leastSessions).toList();
      chosen.add(least[rng.nextInt(least.length)].$1);
    }
    // Zbytek: oblasti, kterým uplynul odstup, nejdéle čekající první
    for (final (area, _) in due) {
      if (chosen.length >= count) break;
      if (!chosen.contains(area)) chosen.add(area);
    }
    // Málo oblastí k zopakování: další nové, pak ty, které odpočívají nejdéle
    final freshLeft = fresh.where((a) => !chosen.contains(a)).toList()..shuffle(rng);
    for (final area in freshLeft) {
      if (chosen.length >= count) break;
      chosen.add(area);
    }
    for (final (area, _) in resting.reversed) {
      if (chosen.length >= count) break;
      if (!exclude.contains(area.id) && !chosen.contains(area)) chosen.add(area);
    }

    return TopicPlan(
      offers: [for (final area in chosen) offer(area)],
      resting: [for (final (area, _) in resting) if (!chosen.contains(area)) area],
      now: now,
    );
  }
}
