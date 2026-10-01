import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger.dart';

/// Repozitář lekcí (sessions), jejich transkriptů a zaznamenaných chyb.
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
    return await (_db.select(_db.transcripts)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  /// Načte transkripty z posledních N sezení pro kontextovou analýzu historie.
  Future<List<Transcript>> getRecentTranscripts({int sessionLimit = 3}) async {
    final recentSessions = await (_db.select(_db.sessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(sessionLimit))
        .get();

    if (recentSessions.isEmpty) return [];

    final sessionIds = recentSessions.map((s) => s.id).toList();

    return await (_db.select(_db.transcripts)
          ..where((t) => t.sessionId.isIn(sessionIds))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  /// Načte všechny transkripty studenta (speaker = 'user') napříč historií pro extrakci profilových dat.
  Future<List<Transcript>> getAllUserTranscripts({int limit = 100}) async {
    return await (_db.select(_db.transcripts)
          ..where((t) => t.speaker.equals('user'))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Sleduje všechny textové záznamy pro konkrétní lekci v reálném čase.
  Stream<List<Transcript>> watchTranscripts(int sessionId) {
    return (_db.select(_db.transcripts)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
  }

  /// Sleduje chyby zaznamenané v konkrétní lekci v reálném čase.
  Stream<List<ErrorLog>> watchErrorLogs(int sessionId) {
    return (_db.select(_db.errorLogs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
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

  /// Uloží záznam o gramatické nebo výslovnostní chybě uživatele.
  Future<Result<int>> addErrorLog({
    required int sessionId,
    required String errorType,
    required String userSaid,
    required String correctForm,
    required String explanation,
  }) async {
    try {
      final id = await _db.into(_db.errorLogs).insert(
        ErrorLogsCompanion.insert(
          sessionId: sessionId,
          errorType: errorType,
          userSaid: userSaid,
          correctForm: correctForm,
          explanation: explanation,
          timestamp: DateTime.now(),
        ),
      );
      return Result.success(id);
    } catch (e, stack) {
      L.e('Chyba při ukládání logu chyby', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se zaznamenat chybu.'));
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

  /// Smaže lekci a všechna související data z databáze a upozorní profil.
  Future<Result<void>> deleteSession(int sessionId) async {
    try {
      // Zjistíme, jestli mažeme tu úplně nejnovější (poslední) lekci.
      // DŮLEŽITÉ: musíme přidat .limit(1) – getSingleOrNull() háže
      // 'Bad state: Too many elements' pokud query vrátí více než 1 řádek.
      final latestSession = await (_db.select(_db.sessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();

      await _db.transaction(() async {
        // Smazání transkriptů
        await (_db.delete(_db.transcripts)..where((t) => t.sessionId.equals(sessionId))).go();
        // Smazání logů chyb
        await (_db.delete(_db.errorLogs)..where((t) => t.sessionId.equals(sessionId))).go();
        // Smazání samotné session
        await (_db.delete(_db.sessions)..where((t) => t.id.equals(sessionId))).go();

        // Aktualizace uživatelského profilu
        final user = await (_db.select(_db.userProfiles)..where((t) => t.id.equals(1))).getSingleOrNull();
        if (user != null) {
          int newTotal = user.totalSessions > 0 ? user.totalSessions - 1 : 0;
          
          if (latestSession != null && latestSession.id == sessionId) {
            // Pokud mažeme poslední lekci, vymažeme z paměti memoryBriefing,
            // aby agent už neodkazoval na smazanou lekci v příštím hovoru.
            await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
              UserProfilesCompanion(
                memoryBriefing: const Value(null),
                totalSessions: Value(newTotal),
              ),
            );
          } else {
            // Jinak jen snížíme počet lekcí
            await (_db.update(_db.userProfiles)..where((t) => t.id.equals(1))).write(
              UserProfilesCompanion(
                totalSessions: Value(newTotal),
              ),
            );
          }
        }
      });
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při mazání session', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se smazat lekci.'));
    }
  }

  /// Načte chyby, ze kterých ještě nevznikla kartička (nejnovější první),
  /// volitelně jen z lekce [sessionId].
  Future<List<ErrorLog>> getErrorLogsWithoutFlashcard({int? sessionId}) {
    final query = _db.select(_db.errorLogs)
      ..where((t) => t.inFlashcard.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    if (sessionId != null) {
      query.where((t) => t.sessionId.equals(sessionId) & t.inFlashcard.equals(false));
    }
    return query.get();
  }

  /// Označí chybu jako zpracovanou do kartičky (nebo vyřazenou z generování kartiček).
  Future<void> markErrorLogInFlashcard(int errorLogId) async {
    await (_db.update(_db.errorLogs)..where((t) => t.id.equals(errorLogId)))
        .write(const ErrorLogsCompanion(inFlashcard: Value(true)));
  }
}
