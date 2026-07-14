import 'package:drift/drift.dart';
import '../database/app_database.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  /// Vytvoří novou session v databázi a vrátí její ID
  Future<int> startNewSession() async {
    return await _db.into(_db.sessions).insert(
      SessionsCompanion.insert(
        startedAt: DateTime.now(),
      ),
    );
  }

  /// Přidá záznam do transkriptu
  Future<void> addTranscript({
    required int sessionId,
    required String speaker,
    required String content,
  }) async {
    await _db.into(_db.transcripts).insert(
      TranscriptsCompanion.insert(
        sessionId: sessionId,
        speaker: speaker,
        content: content,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Uzavře session
  Future<void> closeSession(int sessionId) async {
    await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId))).write(
      SessionsCompanion(
        endedAt: Value(DateTime.now()),
      ),
    );
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

  /// Získá aktuální briefing pro tutora
  Future<String?> getLatestBriefing() async {
    final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
    return user?.memoryBriefing;
  }
}

