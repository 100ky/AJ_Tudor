import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/scenario_repository.dart';

void main() {
  late AppDatabase db;
  late ScenarioRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ScenarioRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ScenarioRepository', () {
    test('replaceScenarios deletes unused scenarios and inserts new ones within transaction', () async {
      // Insert an unused scenario and a used scenario
      final custom1 = await repo.insertScenario(
        title: 'Custom unused',
        description: 'Desc 1',
        tutorInstruction: 'Instruction 1',
      );
      final custom2 = await repo.insertScenario(
        title: 'Custom used',
        description: 'Desc 2',
        tutorInstruction: 'Instruction 2',
      );
      await repo.markScenarioUsed(custom2.id);

      // Now replace with a new scenario
      final newScenario = Scenario(
        id: 0,
        externalId: 'ai_new_1',
        title: 'At the airport',
        description: 'Check-in luggage',
        tutorInstruction: 'Act as airline staff',
        difficulty: 'medium',
        isUsed: false,
        createdAt: DateTime.now(),
      );

      await repo.replaceScenarios([newScenario]);

      final available = await repo.watchAvailableScenarios().first;
      expect(available.length, 1);
      expect(available.first.title, 'At the airport');

      // The used scenario should still exist in database
      final allScenarios = await (db.select(db.scenarios)).get();
      expect(allScenarios.any((s) => s.id == custom2.id && s.isUsed == true), true);
      expect(allScenarios.any((s) => s.id == custom1.id), false);
    });

    test('insertScenario inserts custom scenario into database without wiping existing', () async {
      final scenario = await repo.insertScenario(
        title: 'Pohovor v IT firmě',
        description: 'Role-play technického pohovoru.',
        tutorInstruction: 'Act as a friendly interviewer asking about Flutter.',
        difficulty: 'hard',
      );

      expect(scenario.id, greaterThan(0));
      expect(scenario.title, 'Pohovor v IT firmě');
      expect(scenario.difficulty, 'hard');

      final available = await repo.watchAvailableScenarios().first;
      expect(available.any((s) => s.id == scenario.id), true);
    });
  });
}
