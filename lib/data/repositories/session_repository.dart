import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger.dart';

/// Repozitář pro správu dat souvisejících s výukovými lekcemi (sessions).
/// 
/// Zapouzdřuje přímé volání databáze a poskytuje čisté rozhraní pro zbytek aplikace.
/// Využívá třídu [Result] pro bezpečné zpracování chyb.
class SessionRepository {
  final AppDatabase _db;

  /// Inicializuje repozitář s instancí databáze.
  SessionRepository(this._db);

  /// Vytvoří novou lekci (session) v databázi a vrátí její ID.
  /// 
  /// Automaticky nastaví čas zahájení na aktuální čas.
  Future<Result<int>> startNewSession() async {
    try {
      final id = await _db.into(_db.sessions).insert(
        SessionsCompanion.insert(
          startedAt: DateTime.now(),
        ),
      );
      return Result.success(id);
    } catch (e, stack) {
      L.e('Chyba při zakládání session', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se založit novou lekci.'));
    }
  }

  /// Přidá záznam promluvy (textu) do historie dané lekce.
  /// 
  /// [speaker] může být 'user' (student) nebo 'tutor' (AI).
  Future<Result<void>> addTranscript({
    required int sessionId,
    required String speaker,
    required String content,
  }) async {
    try {
      await _db.into(_db.transcripts).insert(
        TranscriptsCompanion.insert(
          sessionId: sessionId,
          speaker: speaker,
          content: content,
          timestamp: DateTime.now(),
        ),
      );
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při ukládání transkriptu', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se uložit historii hovoru.'));
    }
  }

  /// Označí lekci jako ukončenou a uloží čas konce.
  Future<Result<void>> closeSession(int sessionId) async {
    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId))).write(
        SessionsCompanion(
          endedAt: Value(DateTime.now()),
        ),
      );
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při uzavírání session', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se korektně ukončit lekci.'));
    }
  }

  /// Načte všechny textové záznamy (transkripty) pro konkrétní lekci.
  Future<List<Transcript>> getTranscripts(int sessionId) async {
    return await (_db.select(_db.transcripts)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  /// Aktualizuje výsledky analýzy lekce (shrnutí, plynulost, počet chyb).
  /// 
  /// Volá se typicky po skončení lekce, kdy AI provede vyhodnocení celého hovoru.
  Future<void> updateSessionAnalysis({
    required int sessionId,
    required String topicSummary,
    required double fluencyScore,
    required int totalErrors,
  }) async {
    await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId))).write(
      SessionsCompanion(
        topicSummary: Value(topicSummary),
        fluencyScore: Value(fluencyScore),
        totalErrors: Value(totalErrors),
      ),
    );
  }

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
  Future<void> updateUserVocabulary(List<String> newWords) async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (user == null) return;

    final List<dynamic> currentVocab = jsonDecode(user.vocabulary);
    final Set<String> vocabSet = Set<String>.from(currentVocab.map((e) => e.toString()));
    
    vocabSet.addAll(newWords.map((e) => e.trim()));
    
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
      UserProfilesCompanion(
        vocabulary: Value(jsonEncode(vocabSet.toList())),
      ),
    );
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

  /// Uloží záznam o gramatické nebo výslovnostní chybě uživatele.
  Future<Result<void>> addErrorLog({
    required int sessionId,
    required String errorType,
    required String userSaid,
    required String correctForm,
    required String explanation,
  }) async {
    try {
      await _db.into(_db.errorLogs).insert(
        ErrorLogsCompanion.insert(
          sessionId: sessionId,
          errorType: errorType,
          userSaid: userSaid,
          correctForm: correctForm,
          explanation: explanation,
          timestamp: DateTime.now(),
        ),
      );
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při logování lingvistické chyby', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se uložit záznam o chybě.'));
    }
  }

  /// Načte všechny chyby zaznamenané v konkrétní lekci.
  Future<List<ErrorLog>> getErrorLogs(int sessionId) async {
    return await (_db.select(_db.errorLogs)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  /// Sleduje všechny zaznamenané chyby (např. pro zobrazení v dashboardu statistik).
  Stream<List<ErrorLog>> watchAllErrorLogs() {
    return (_db.select(_db.errorLogs)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  /// Sleduje seznam všech absolvovaných lekcí seřazený od nejnovější.
  Stream<List<Session>> watchAllSessions() {
    return (_db.select(_db.sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();
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

  // --- SCÉNÁŘE ---

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

  /// Načte aktuální uživatelský profil (pokud existuje).
  Future<UserProfile?> getUserProfile() async {
    return await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
  }
}

