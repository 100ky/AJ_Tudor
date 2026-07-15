import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  /// Vytvoří novou session v databázi a vrátí její ID
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

  /// Přidá záznam do transkriptu
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

  /// Uzavře session
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

  /// Načte transkripty pro danou session
  Future<List<Transcript>> getTranscripts(int sessionId) async {
    return await (_db.select(_db.transcripts)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  /// Aktualizuje výsledky analýzy session
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

  /// Aktualizuje briefing v profilu uživatele
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

  /// Aktualizuje slovní zásobu uživatele
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

  /// Získá aktuální briefing pro tutora
  Future<Result<String?>> getLatestBriefing() async {
    try {
      final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
      return Result.success(user?.memoryBriefing);
    } catch (e, stack) {
      L.e('Chyba při načítání briefingu', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se načíst paměť tutora.'));
    }
  }

  /// Sleduje změny v profilu uživatele
  Stream<UserProfile?> watchUserProfile() {
    return (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).watchSingleOrNull();
  }

  /// Přidá záznam o chybě
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

  /// Načte všechny chyby pro danou session
  Future<List<ErrorLog>> getErrorLogs(int sessionId) async {
    return await (_db.select(_db.errorLogs)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  /// Sleduje všechny chyby (pro dashboard)
  Stream<List<ErrorLog>> watchAllErrorLogs() {
    return (_db.select(_db.errorLogs)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  /// Načte seznam všech sessions
  Stream<List<Session>> watchAllSessions() {
    return (_db.select(_db.sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();
  }

  /// Smaže paměť uživatele (včetně briefingu)
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

  // --- SCÉNÁŘE ---

  /// Uloží nové scénáře (a smaže staré nepoužité)
  Future<void> replaceScenarios(List<Scenario> newScenarios) async {
    await _db.transaction(() async {
      // Smažeme staré, které nebyly využity (nebo prostě všechny nepoužité)
      await (_db.delete(_db.scenarios)..where((t) => t.isUsed.equals(false))).go();
      
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

  /// Načte dostupné scénáře
  Stream<List<Scenario>> watchAvailableScenarios() {
    return (_db.select(_db.scenarios)..where((t) => t.isUsed.equals(false))).watch();
  }

  /// Označí scénář jako použitý
  Future<void> markScenarioUsed(int id) async {
    await (_db.update(_db.scenarios)..where((t) => t.id.equals(id))).write(
      const ScenariosCompanion(isUsed: Value(true)),
    );
  }

  /// Načte profil uživatele
  Future<UserProfile?> getUserProfile() async {
    return await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
  }
}

