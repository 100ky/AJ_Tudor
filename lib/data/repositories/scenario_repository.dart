import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Repozitář konverzačních scénářů (role-play), které nabízí hlasový tutor.
class ScenarioRepository {
  final AppDatabase _db;

  /// Inicializuje repozitář s instancí databáze.
  ScenarioRepository(this._db);

  /// Nahradí staré nevyužité konverzační scénáře nově vygenerovanými.
  /// 
  /// Celý proces probíhá v jedné DB transakci pro zajištění konzistence.
  Future<void> replaceScenarios(List<Scenario> newScenarios) async {
    await _db.transaction(() async {
      // Odstranění všech scénářů, které uživatel ještě nepoužil
      await (_db.delete(_db.scenarios)..where((t) => t.isUsed.equals(false))).go();
      
      // Vložení nových scénářů
      for (var s in newScenarios) {
        await _db.into(_db.scenarios).insert(
          ScenariosCompanion.insert(
            externalId: s.externalId,
            title: s.title,
            description: s.description,
            tutorInstruction: s.tutorInstruction,
            difficulty: s.difficulty,
          ),
        );
      }
    });
  }

  /// Sleduje seznam dostupných (nepoužitých) scénářů pro výběr v UI.
  Stream<List<Scenario>> watchAvailableScenarios() {
    return (_db.select(_db.scenarios)..where((t) => t.isUsed.equals(false))).watch();
  }

  /// Označí vybraný scénář jako použitý, aby se již nenabízel.
  Future<void> markScenarioUsed(int id) async {
    await (_db.update(_db.scenarios)..where((t) => t.id.equals(id))).write(
      const ScenariosCompanion(isUsed: Value(true)),
    );
  }

  /// Vloží jeden nový vlastní scénář do databáze a vrátí vytvořený [Scenario].
  Future<Scenario> insertScenario({
    required String title,
    required String description,
    required String tutorInstruction,
    String difficulty = 'medium',
  }) async {
    final externalId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final id = await _db.into(_db.scenarios).insert(
      ScenariosCompanion.insert(
        externalId: externalId,
        title: title,
        description: description,
        tutorInstruction: tutorInstruction,
        difficulty: difficulty,
      ),
    );
    return Scenario(
      id: id,
      externalId: externalId,
      title: title,
      description: description,
      tutorInstruction: tutorInstruction,
      difficulty: difficulty,
      isUsed: false,
      createdAt: DateTime.now(),
    );
  }
}
