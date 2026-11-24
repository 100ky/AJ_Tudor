import 'dart:math';

import 'package:aj_tudor/data/models/topic_record.dart';
import 'package:aj_tudor/services/topics/topic_catalog.dart';
import 'package:aj_tudor/services/topics/topic_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 22, 18);

  TopicRecord record(int session, String area, int daysAgo, [String title = 'téma']) => TopicRecord(
        sessionId: session,
        areaId: area,
        title: title,
        discussedAt: now.subtract(Duration(days: daysAgo)),
      );

  group('TopicCatalog', () {
    test('every area has a unique id, a description and seeds', () {
      expect(TopicCatalog.ids.toSet(), hasLength(TopicCatalog.areas.length));
      for (final area in TopicCatalog.areas) {
        expect(area.description, isNotEmpty);
        expect(area.seeds.length, greaterThanOrEqualTo(4));
      }
      expect(TopicCatalog.byId('technologie')?.label, 'Technologie a internet');
      expect(TopicCatalog.byId('neexistuje'), isNull);
    });
  });

  group('TopicPlanner.restAfter', () {
    test('the rest grows with every lesson in the area and never exceeds a week', () {
      expect(TopicPlanner.restAfter(1), const Duration(days: 2));
      expect(TopicPlanner.restAfter(2), const Duration(days: 4));
      expect(TopicPlanner.restAfter(3), const Duration(days: 7));
      expect(TopicPlanner.restAfter(20), const Duration(days: 7));
    });

    test('the longest rest follows the setting', () {
      expect(TopicPlanner.restAfter(3, maxRestDays: 14), const Duration(days: 8));
      expect(TopicPlanner.restAfter(5, maxRestDays: 14), const Duration(days: 14));
      expect(TopicPlanner.restAfter(3, maxRestDays: 3), const Duration(days: 3));
    });
  });

  group('TopicPlanner.plan', () {
    test('without history it offers three new areas', () {
      final plan = TopicPlanner.plan(const [], now: now, random: Random(1));
      expect(plan.offers, hasLength(3));
      expect(plan.offers.every((o) => o.isNew), isTrue);
      expect(plan.resting, isEmpty);
    });

    test('an area discussed yesterday rests, one discussed long ago comes back', () {
      // Práce a IT ve třech lekcích po sobě: 7 dní odpočinek
      final records = [
        record(1, 'prace', 3),
        record(2, 'prace', 2),
        record(3, 'technologie', 1),
        record(4, 'cestovani', 6, 'Výlet do Toulovcových Maštalí'),
        record(5, 'zvirata', 0, 'Králík Dobas'),
      ];
      final plan = TopicPlanner.plan(records, now: now, random: Random(2));
      final offered = plan.offers.map((o) => o.area.id).toList();

      expect(plan.restingLabels, containsAll(['Práce a kariéra', 'Technologie a internet', 'Zvířata a mazlíčci']));
      expect(offered, isNot(contains('prace')));
      expect(offered, isNot(contains('technologie')));
      // Cestování (2 dny odpočinku) čeká už 6 dní
      expect(offered, contains('cestovani'));
      final travel = plan.offers.firstWhere((o) => o.area.id == 'cestovani');
      expect(travel.isNew, isFalse);
      expect(travel.recentTitles, ['Výlet do Toulovcových Maštalí']);
      expect(travel.describe(now), contains('k zopakování, naposledy před 6 dny (Výlet do Toulovcových Maštalí)'));
    });

    test('one of three offered areas is always new while new areas remain', () {
      final records = [
        for (final (i, area) in TopicCatalog.areas.take(15).indexed) record(i + 1, area.id, 10 + i),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final plan = TopicPlanner.plan(records, now: now, random: Random(seed));
        expect(plan.offers, hasLength(3));
        expect(plan.offers.where((o) => o.isNew), hasLength(1));
        // Dvě místa pro zopakování dostanou oblasti, které čekají nejdéle
        expect(plan.offers.where((o) => !o.isNew).map((o) => o.area.id),
            containsAll([TopicCatalog.areas[14].id, TopicCatalog.areas[13].id]));
      }
    });

    test('when every area was discussed, the least discussed one takes the new slot', () {
      final records = [
        for (final (i, area) in TopicCatalog.areas.indexed) ...[
          record(100 + i, area.id, 20),
          if (area.id != 'dilemata') record(200 + i, area.id, 15),
        ],
      ];
      final plan = TopicPlanner.plan(records, now: now, random: Random(3));
      expect(plan.offers.first.area.id, 'dilemata');
      expect(plan.offers.any((o) => o.isNew), isFalse);
      expect(plan.offers, hasLength(3));
    });

    test('excluded areas are not offered', () {
      final plan = TopicPlanner.plan(const [], now: now, exclude: {for (final a in TopicCatalog.areas.skip(2)) a.id});
      expect(plan.offers.map((o) => o.area.id), unorderedEquals([TopicCatalog.areas[0].id, TopicCatalog.areas[1].id]));
    });

    test('records of an unknown area are ignored', () {
      final plan = TopicPlanner.plan([record(1, 'zmizela', 0)], now: now, random: Random(4));
      expect(plan.resting, isEmpty);
      expect(plan.offers.every((o) => o.isNew), isTrue);
    });

    test('the offers block numbers the areas and gives seeds', () {
      final plan = TopicPlanner.plan(const [], now: now, random: Random(5));
      final block = plan.offersBlock();
      expect(block, startsWith('1. '));
      expect(block, contains('NOVÁ oblast'));
      expect(block, contains('Náměty: '));
    });
  });
}
