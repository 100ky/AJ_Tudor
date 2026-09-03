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
    return await (_db.select(_db.transcripts)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
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

  // ── Smart Flashcards & SRS Repozitář ──────────────────────────────────────

  /// Vloží novou kartičku do databáze (např. z chytré bubliny nebo analýzy chyb).
  Future<Result<int>> addFlashcard({
    required String frontText,
    required String backText,
    required String explanation,
    String errorType = 'grammar',
    String? sourceSentence,
    int? errorLogId,
  }) async {
    try {
      final now = DateTime.now();
      final id = await _db.into(_db.flashcards).insert(
            FlashcardsCompanion.insert(
              frontText: frontText,
              backText: backText,
              explanation: explanation,
              errorType: Value(errorType),
              sourceSentence: Value(sourceSentence),
              errorLogId: Value(errorLogId),
              nextReviewAt: now, // Ihned připraveno k prvnímu procvičení
              createdAt: now,
            ),
          );
      L.i('Kartička #$id úspěšně vytvořena: "$frontText" -> "$backText"');

      // 1. Označíme odpovídající error_log jako zařazený do kartičky
      if (errorLogId != null) {
        await (_db.update(_db.errorLogs)..where((t) => t.id.equals(errorLogId)))
            .write(const ErrorLogsCompanion(inFlashcard: Value(true)));
      }

      // 2. Označíme odpovídající věty v transkriptech a logu chyb
      if (sourceSentence != null && sourceSentence.trim().isNotEmpty) {
        final cleanSentence = sourceSentence.trim();
        await (_db.update(_db.transcripts)
              ..where((t) => t.content.like('%$cleanSentence%')))
            .write(const TranscriptsCompanion(inFlashcard: Value(true)));
        await (_db.update(_db.errorLogs)
              ..where((t) => t.userSaid.equals(cleanSentence)))
            .write(const ErrorLogsCompanion(inFlashcard: Value(true)));
      }

      return Result.success(id);
    } catch (e, stack) {
      L.e('Chyba při vytváření kartičky', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se vytvořit kartičku.'));
    }
  }

  /// Sleduje proud všech kartiček, které jsou připravené k dnešnímu procvičení.
  Stream<List<Flashcard>> watchDueFlashcards() {
    final now = DateTime.now();
    return (_db.select(_db.flashcards)
          ..where((t) => t.nextReviewAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
        .watch();
  }

  /// Načte seznam kartiček připravených k procvičení.
  Future<List<Flashcard>> getDueFlashcards() async {
    final now = DateTime.now();
    return await (_db.select(_db.flashcards)
          ..where((t) => t.nextReviewAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
        .get();
  }

  /// Sleduje všechny existující kartičky v databázi.
  Stream<List<Flashcard>> watchAllFlashcards() {
    return (_db.select(_db.flashcards)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Načte všechny kartičky v databázi.
  Future<List<Flashcard>> getAllFlashcards() async {
    return await (_db.select(_db.flashcards)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Aktualizuje stav kartičky po studentově procvičení (SRS algoritmus).
  /// 
  /// [rating]:
  /// - `0` (Znovu / Again): Reset intervalu na 1 den, mastery klesá.
  /// - `1` (Těžké / Hard): Interval se prodlouží 1.2x.
  /// - `2` (Dobré / Good): Interval se prodlouží 2.0x.
  /// - `3` (Snadné / Easy): Interval se prodlouží 3.0x, mastery roste.
  Future<Result<void>> reviewFlashcard({
    required int flashcardId,
    required int rating,
  }) async {
    try {
      final card = await (_db.select(_db.flashcards)
            ..where((t) => t.id.equals(flashcardId)))
          .getSingleOrNull();

      if (card == null) {
        return Result.failure(DatabaseFailure('Kartička nebyla nalezena.'));
      }

      int newRepetition = card.repetitionCount;
      int newInterval = card.intervalDays;
      double newMastery = card.masteryScore;

      switch (rating) {
        case 0: // Again
          newRepetition = 0;
          newInterval = 1;
          newMastery = (newMastery - 0.2).clamp(0.0, 1.0);
          break;
        case 1: // Hard
          newRepetition += 1;
          newInterval = (newInterval * 1.2).ceil().clamp(1, 60);
          newMastery = (newMastery + 0.05).clamp(0.0, 1.0);
          break;
        case 2: // Good
          newRepetition += 1;
          newInterval = (newInterval * 2.0).ceil().clamp(2, 90);
          newMastery = (newMastery + 0.15).clamp(0.0, 1.0);
          break;
        case 3: // Easy
          newRepetition += 1;
          newInterval = (newInterval * 3.0).ceil().clamp(4, 180);
          newMastery = (newMastery + 0.25).clamp(0.0, 1.0);
          break;
      }

      final nextReview = DateTime.now().add(Duration(days: newInterval));

      await (_db.update(_db.flashcards)..where((t) => t.id.equals(flashcardId))).write(
        FlashcardsCompanion(
          intervalDays: Value(newInterval),
          repetitionCount: Value(newRepetition),
          masteryScore: Value(newMastery),
          nextReviewAt: Value(nextReview),
        ),
      );

      L.i('Kartička #$flashcardId ohodnocena ($rating). Nový interval: $newInterval dní.');
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při hodnocení kartičky', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se uložit hodnocení kartičky.'));
    }
  }

  /// Smaže konkrétní kartičku.
  Future<Result<void>> deleteFlashcard(int id) async {
    try {
      await (_db.delete(_db.flashcards)..where((t) => t.id.equals(id))).go();
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při mazání kartičky', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se smazat kartičku.'));
    }
  }

  /// Vytvoří kartičku přímo ze záznamu v historii/transkriptu a označí větu jako uloženou.
  Future<Result<int>> createFlashcardFromTranscript({
    required int transcriptId,
    required String userSaid,
    required String correctForm,
    required String explanation,
    String errorType = 'grammar',
    int? errorLogId,
  }) async {
    try {
      final res = await addFlashcard(
        frontText: 'Jak správně říct: "$userSaid"?',
        backText: correctForm,
        explanation: explanation.isNotEmpty ? explanation : 'Oprava z konverzace',
        errorType: errorType,
        sourceSentence: userSaid,
        errorLogId: errorLogId,
      );

      if (res.isSuccess) {
        await (_db.update(_db.transcripts)..where((t) => t.id.equals(transcriptId)))
            .write(const TranscriptsCompanion(inFlashcard: Value(true)));
      }
      return res;
    } catch (e, stack) {
      L.e('Chyba při vytváření kartičky z transkriptu', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se vytvořit kartičku.'));
    }
  }

  /// Automaticky vygeneruje nové kartičky z dosud nezpracovaných chyb studenta.
  /// 
  /// [sessionId] volitelné filtrování na konkrétní lekci.
  /// [limit] maximální počet kartiček vytvořených v jedné dávce (výchozí 15).
  Future<Result<int>> generateFlashcardsFromErrors({
    int? sessionId,
    int limit = 15,
  }) async {
    try {
      // 1. Získáme chyby z databáze
      var query = _db.select(_db.errorLogs)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
      
      if (sessionId != null) {
        query = query..where((t) => t.sessionId.equals(sessionId));
      }

      final allErrors = await query.get();
      if (allErrors.isEmpty) {
        return Result.success(0);
      }

      // 2. Načteme existující kartičky pro kontrolu duplicit (podle sourceSentence nebo backText)
      final existingCards = await getAllFlashcards();
      final existingBackTexts = existingCards.map((c) => c.backText.trim().toLowerCase()).toSet();
      final existingSources = existingCards.map((c) => (c.sourceSentence ?? '').trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
      final existingErrorLogIds = existingCards.map((c) => c.errorLogId).whereType<int>().toSet();

      int createdCount = 0;
      final seenNewPhrases = <String>{};

      for (final err in allErrors) {
        if (createdCount >= limit) break;

        final userSaid = err.userSaid.trim();
        final correctForm = err.correctForm.trim();
        if (userSaid.isEmpty || correctForm.isEmpty) continue;

        final lowerSaid = userSaid.toLowerCase();
        final lowerCorrect = correctForm.toLowerCase();

        // Přeskočit pokud už tato fráze nebo chyba v kartičkách existuje
        if (existingErrorLogIds.contains(err.id) ||
            existingBackTexts.contains(lowerCorrect) ||
            existingSources.contains(lowerSaid) ||
            seenNewPhrases.contains(lowerCorrect)) {
          // Alespoň synchronizujeme inFlashcard příznak
          if (!err.inFlashcard) {
            await (_db.update(_db.errorLogs)..where((t) => t.id.equals(err.id)))
                .write(const ErrorLogsCompanion(inFlashcard: Value(true)));
          }
          continue;
        }

        seenNewPhrases.add(lowerCorrect);

        final frontText = 'Jak opravit / říct: "$userSaid"?';
        final cardRes = await addFlashcard(
          frontText: frontText,
          backText: correctForm,
          explanation: err.explanation.isNotEmpty ? err.explanation : 'Oprava chyby z konverzace',
          errorType: err.errorType,
          sourceSentence: userSaid,
          errorLogId: err.id,
        );

        if (cardRes.isSuccess) {
          createdCount++;
        }
      }

      L.i('Úspěšně vygenerováno $createdCount kartiček z chyb.');
      return Result.success(createdCount);
    } catch (e, stack) {
      L.e('Chyba při hromadném generování kartiček z chyb', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se vygenerovat kartičky z chyb.'));
    }
  }
}



