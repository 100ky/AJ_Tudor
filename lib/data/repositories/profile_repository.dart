import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger.dart';

/// Repozitář profilu studenta: dlouhodobá paměť tutora, slovní zásoba,
/// opakující se chyby, fakta „O mně“, cílová úroveň a připravené téma.
///
/// Aplikace pracuje s jediným profilem (ID 1).
class ProfileRepository {
  final AppDatabase _db;

  /// Inicializuje repozitář s instancí databáze.
  ProfileRepository(this._db);

  /// Aktualizuje "dlouhodobou paměť" tutora (briefing) v profilu uživatele.
  /// 
  /// Briefing obsahuje shrnutí toho, co si student z lekce odnesl a na čem je třeba pracovat.
  Future<void> updateUserMemory(String briefing) async {
    // Pro zjednodušení předpokládáme ID 1 pro hlavního uživatele
    final exists = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (exists != null) {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
        UserProfilesCompanion(
          memoryBriefing: Value(briefing),
          lastSessionAt: Value(DateTime.now()),
          totalSessions: Value(exists.totalSessions + 1),
        ),
      );
    } else {
      // Pokud profil neexistuje, vytvoříme nový s výchozími hodnotami
      await _db.into(_db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: const Value(1),
          memoryBriefing: Value(briefing),
          lastSessionAt: Value(DateTime.now()),
          totalSessions: const Value(1),
          nativeLanguage: const Value('cs'),
          targetLevel: const Value('B1'),
          recurringErrors: const Value('[]'),
          vocabulary: const Value('[]'),
          topicPreferences: const Value('[]'),
        ),
      );
    }
  }

  /// Aktualizuje seznam známých slovíček uživatele.
  /// 
  /// Přidá nová slova do existujícího JSON pole, přičemž duplicity jsou automaticky odstraněny.
  /// Udržuje maximálně 50 nejnovějších slovíček, aby se zbytečně nenafukoval systémový prompt.
  Future<void> updateUserVocabulary(List<String> newWords) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    final List<dynamic> currentVocab = jsonDecode(user.vocabulary);
    // Převedeme na List místo Set, abychom zachovali pořadí (nejnovější na konci)
    final List<String> vocabList = currentVocab.map((e) => e.toString()).toList();
    
    for (final word in newWords.map((e) => e.trim())) {
      vocabList.remove(word); // Odstraníme duplicitu, pokud existuje
      vocabList.add(word);    // Přidáme na konec (nejnovější)
    }
    
    // Udržíme pouze posledních 50 slovíček pro zamezení nafukování promptu
    final List<String> trimmedVocab = vocabList.length > 50
        ? vocabList.sublist(vocabList.length - 50)
        : vocabList;
    
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      UserProfilesCompanion(
        vocabulary: Value(jsonEncode(trimmedVocab)),
      ),
    );
  }

  /// Aktualizuje seznam opakujících se chyb uživatele v profilu.
  /// 
  /// Přidá nové chyby do existujícího JSON pole, přičemž duplicity jsou odstraněny a počet je limitován (např. max 10 chyb).
  Future<void> updateUserRecurringErrors(List<String> newErrors) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    final List<dynamic> currentErrors = jsonDecode(user.recurringErrors);
    final Set<String> errorsSet = Set<String>.from(currentErrors.map((e) => e.toString()));
    
    errorsSet.addAll(newErrors.map((e) => e.trim()));
    
    // Udržíme pouze posledních 10 chyb pro zamezení nafukování promptu
    List<String> updatedErrorsList = errorsSet.toList();
    if (updatedErrorsList.length > 10) {
      updatedErrorsList = updatedErrorsList.sublist(updatedErrorsList.length - 10);
    }

    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      UserProfilesCompanion(
        recurringErrors: Value(jsonEncode(updatedErrorsList)),
      ),
    );
  }

  /// Prořezává (odstraňuje) vyřešené chyby z profilu studenta (Memory Pruning).
  ///
  /// Porovnává seznam [resolvedErrors] z analýzy s aktuálními `recurringErrors` v profilu.
  /// Používá case-insensitive `contains` pro fuzzy shodu, protože formulace chyb
  /// se mohou mezi analýzami mírně lišit.
  Future<void> pruneResolvedErrors(List<String> resolvedErrors) async {
    if (resolvedErrors.isEmpty) return;

    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    final List<dynamic> currentErrors = jsonDecode(user.recurringErrors);
    final List<String> errorsList = currentErrors.map((e) => e.toString()).toList();

    final int originalCount = errorsList.length;

    // Pro každou vyřešenou chybu hledáme sémantickou shodu v existujících záznamech
    errorsList.removeWhere((existingError) {
      final lowerExisting = existingError.toLowerCase();
      return resolvedErrors.any((resolved) =>
          lowerExisting.contains(resolved.toLowerCase()) ||
          resolved.toLowerCase().contains(lowerExisting));
    });

    if (errorsList.length < originalCount) {
      L.i('Memory Pruning: Odstraněno ${originalCount - errorsList.length} vyřešených chyb z profilu.');
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
        UserProfilesCompanion(
          recurringErrors: Value(jsonEncode(errorsList)),
        ),
      );
    }
  }

  /// Aktualizuje seznam zapamatovaných osobních faktů o studentovi ("O mně").
  Future<void> updateUserFacts(List<String> newFacts) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    List<dynamic> currentFacts = [];
    try {
      currentFacts = jsonDecode(user.userFacts);
    } catch (_) {}

    final List<String> factsList = currentFacts.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();

    for (final fact in newFacts.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      final isDuplicate = factsList.any((existing) =>
          existing.toLowerCase() == fact.toLowerCase() ||
          existing.toLowerCase().contains(fact.toLowerCase()) ||
          fact.toLowerCase().contains(existing.toLowerCase()));
      if (!isDuplicate) {
        factsList.add(fact);
      }
    }

    // Omezení na max 40 faktů pro zamezení přetížení promptu
    final trimmedFacts = factsList.length > 40
        ? factsList.sublist(factsList.length - 40)
        : factsList;

    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      UserProfilesCompanion(
        userFacts: Value(jsonEncode(trimmedFacts)),
      ),
    );
  }

  /// Přidá jednotlivý fakt do "O mně" (např. ručně z UI).
  Future<void> addUserFact(String fact) async {
    final clean = fact.trim();
    if (clean.isEmpty) return;
    await updateUserFacts([clean]);
  }

  /// Odebere konkrétní fakt z "O mně".
  Future<void> removeUserFact(String fact) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    List<dynamic> currentFacts = [];
    try {
      currentFacts = jsonDecode(user.userFacts);
    } catch (_) {}

    final List<String> factsList = currentFacts.map((e) => e.toString().trim()).toList();
    factsList.removeWhere((item) => item.toLowerCase() == fact.trim().toLowerCase());

    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      UserProfilesCompanion(
        userFacts: Value(jsonEncode(factsList)),
      ),
    );
  }

  /// Načte seznam zapamatovaných faktů jako `List<String>`.
  Future<List<String>> getUserFacts() async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return [];
    try {
      final List<dynamic> raw = jsonDecode(user.userFacts);
      return raw.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Uloží téma připravené agentem při startu aplikace pro příští hlasovou lekci.
  Future<void> savePreparedTopic(String topicJson) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user != null) {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
        UserProfilesCompanion(
          preparedTopic: Value(topicJson),
          preparedTopicAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Vymaže připravené téma (např. po jeho spotřebování v lekci).
  Future<void> clearPreparedTopic() async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user != null) {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
        const UserProfilesCompanion(
          preparedTopic: Value(null),
          preparedTopicAt: Value(null),
        ),
      );
    }
  }

  /// Načte připravené téma, pokud existuje.
  Future<String?> getPreparedTopic() async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    return user?.preparedTopic;
  }

  /// Načte poslední uložený briefing (paměť) pro potřeby AI tutora.
  Future<Result<String?>> getLatestBriefing() async {
    try {
      final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
      return Result.success(user?.memoryBriefing);
    } catch (e, stack) {
      L.e('Chyba při načítání briefingu', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se načíst paměť tutora.'));
    }
  }

  /// Stream pro sledování změn v uživatelském profilu (reaktivní UI).
  Stream<UserProfile?> watchUserProfile() {
    return (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).watchSingleOrNull();
  }

  /// Resetuje veškerý pokrok a paměť uživatele (návrat do výchozího stavu).
  Future<void> resetUserMemory() async {
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      const UserProfilesCompanion(
        memoryBriefing: Value(null),
        totalSessions: Value(0),
        recurringErrors: Value('[]'),
        vocabulary: Value('[]'),
        topicPreferences: Value('[]'),
        userFacts: Value('[]'),
        preparedTopic: Value(null),
        preparedTopicAt: Value(null),
        targetLevel: Value('B1'),
      ),
    );
  }

  /// Aktualizuje preferovanou cílovou úroveň angličtiny (např. A2, B2, C1).
  Future<void> updateTargetLevel(String level) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user != null) {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
        UserProfilesCompanion(
          targetLevel: Value(level),
        ),
      );
    } else {
      await _db.into(_db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: const Value(1),
          memoryBriefing: const Value(null),
          lastSessionAt: Value(DateTime.now()),
          totalSessions: const Value(0),
          nativeLanguage: const Value('cs'),
          targetLevel: Value(level),
          recurringErrors: const Value('[]'),
          vocabulary: const Value('[]'),
          topicPreferences: const Value('[]'),
        ),
      );
    }
  }

  /// Načte aktuální uživatelský profil (pokud existuje).
  Future<UserProfile?> getUserProfile() async {
    return await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
  }
}

/// Dekódované seznamy z JSON sloupců profilu (pro UI a prompty).
extension UserProfileLists on UserProfile {
  /// Slovní zásoba studenta (nejnovější slovíčka na konci).
  List<String> get vocabularyList => _decodeStringList(vocabulary);

  /// Osobní fakta „O mně“.
  List<String> get userFactsList => _decodeStringList(userFacts);

  /// Opakující se chyby studenta.
  List<String> get recurringErrorsList => _decodeStringList(recurringErrors);
}

List<String> _decodeStringList(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
  } catch (_) {}
  return <String>[];
}
