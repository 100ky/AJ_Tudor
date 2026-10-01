import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/flashcard_stats.dart';
import '../models/srs_scheduler.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/result.dart';
import '../../core/utils/logger.dart';

/// Repozitář kartiček Smart Flashcards: ukládání, statistiky a SRS opakování.
class FlashcardRepository {
  final AppDatabase _db;

  /// Inicializuje repozitář s instancí databáze.
  FlashcardRepository(this._db);

  /// Vloží novou kartičku do databáze (např. z chytré bubliny nebo analýzy chyb).
  /// Pokud kartička se stejným backText nebo errorLogId již existuje, přeskočí vytvoření
  /// a vrátí ID existující kartičky (zachování SRS pokroku).
  Future<Result<int>> addFlashcard({
    required String frontText,
    required String backText,
    required String explanation,
    String errorType = 'grammar',
    String? sourceSentence,
    int? errorLogId,
  }) async {
    try {
      // ── Kontrola duplicit ─────────────────────────────────────────────
      // Pokud kartička se stejným errorLogId nebo backText už existuje,
      // nevytváříme duplikát (zachováme SRS pokrok stávající kartičky).
      if (errorLogId != null) {
        final existingByError = await (_db.select(_db.flashcards)
              ..where((t) => t.errorLogId.equals(errorLogId))
              ..limit(1))
            .getSingleOrNull();
        if (existingByError != null) {
          L.i('Kartička pro errorLogId=$errorLogId již existuje (#${existingByError.id}), přeskakuji.');
          return Result.success(existingByError.id);
        }
      }

      final existingByText = await (_db.select(_db.flashcards)
            ..where((t) => t.backText.lower().equals(backText.trim().toLowerCase()))
            ..limit(1))
          .getSingleOrNull();
      if (existingByText != null) {
        L.i('Kartička s backText="$backText" již existuje (#${existingByText.id}), přeskakuji.');
        return Result.success(existingByText.id);
      }
      // ── Konec kontroly duplicit ────────────────────────────────────────

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
  /// Kartičky s masteryScore >= 1.0 se považují za plně naučené a nevrací se.
  ///
  /// Aktuální čas vyhodnocuje SQLite při každém přepočtu dotazu, takže ani dlouho
  /// otevřený stream nepoužívá čas z okamžiku, kdy vznikl.
  Stream<List<Flashcard>> watchDueFlashcards() {
    return (_db.select(_db.flashcards)
          ..where((t) =>
              t.nextReviewAt.isSmallerOrEqual(currentDateAndTime) &
              t.masteryScore.isSmallerThanValue(1.0))
          ..orderBy([(t) => OrderingTerm.asc(t.nextReviewAt)]))
        .watch();
  }

  /// Načte seznam kartiček připravených k procvičení.
  /// Kartičky s masteryScore >= 1.0 se považují za plně naučené a nevrací se.
  Future<List<Flashcard>> getDueFlashcards() async {
    final now = DateTime.now();
    return await (_db.select(_db.flashcards)
          ..where((t) => t.nextReviewAt.isSmallerOrEqualValue(now) & t.masteryScore.isSmallerThanValue(1.0))
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

  /// Pomocná metoda pro výpočet agregovaných statistik kartiček z lehkého dotazu.
  FlashcardStats _computeFlashcardStats(List<TypedResult> rows) {
    if (rows.isEmpty) return const FlashcardStats.empty();

    final now = DateTime.now();
    final total = rows.length;
    int due = 0;
    int mastered = 0;
    int learning = 0;
    int newCards = 0;
    double totalMastery = 0.0;

    for (final row in rows) {
      final nextReviewAt = row.read(_db.flashcards.nextReviewAt);
      final masteryScore = row.read(_db.flashcards.masteryScore) ?? 0.0;

      if (nextReviewAt != null && (nextReviewAt.isBefore(now) || nextReviewAt.isAtSameMomentAs(now))) {
        due++;
      }
      if (masteryScore >= 0.8) {
        mastered++;
      } else if (masteryScore > 0.0) {
        learning++;
      } else {
        newCards++;
      }
      totalMastery += masteryScore;
    }

    return FlashcardStats(
      totalCards: total,
      dueCards: due,
      masteredCards: mastered,
      learningCards: learning,
      newCards: newCards,
      averageMastery: totalMastery / total,
    );
  }

  /// Sleduje agregované statistiky kartiček a stavu ovládnutí látky (Mastery).
  /// 
  /// Optimalizováno: vybírá pouze sloupce `masteryScore` a `nextReviewAt` bez řazení a těžkých textových polí.
  Stream<FlashcardStats> watchFlashcardStats() {
    final query = _db.selectOnly(_db.flashcards)
      ..addColumns([_db.flashcards.masteryScore, _db.flashcards.nextReviewAt]);
    return query.watch().map(_computeFlashcardStats);
  }

  /// Načte jednorázově agregované statistiky kartiček.
  /// 
  /// Optimalizováno: vybírá pouze sloupce `masteryScore` a `nextReviewAt` bez řazení a těžkých textových polí.
  Future<FlashcardStats> getFlashcardStats() async {
    final query = _db.selectOnly(_db.flashcards)
      ..addColumns([_db.flashcards.masteryScore, _db.flashcards.nextReviewAt]);
    final rows = await query.get();
    return _computeFlashcardStats(rows);
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

      final update = SrsScheduler.review(
        intervalDays: card.intervalDays,
        repetitionCount: card.repetitionCount,
        masteryScore: card.masteryScore,
        rating: rating,
      );

      await (_db.update(_db.flashcards)..where((t) => t.id.equals(flashcardId))).write(
        FlashcardsCompanion(
          intervalDays: Value(update.intervalDays),
          repetitionCount: Value(update.repetitionCount),
          masteryScore: Value(update.masteryScore),
          nextReviewAt: Value(update.nextReviewAt),
        ),
      );

      L.i('Kartička #$flashcardId ohodnocena ($rating). Nový interval: ${update.intervalDays} dní.');
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

  /// Aktualizuje přední text (české zadání) konkrétní kartičky.
  Future<Result<void>> updateFlashcardFrontText(int id, String newFrontText) async {
    try {
      await (_db.update(_db.flashcards)..where((t) => t.id.equals(id))).write(
        FlashcardsCompanion(
          frontText: Value(newFrontText),
        ),
      );
      return Result.success(null);
    } catch (e, stack) {
      L.e('Chyba při aktualizaci textu kartičky', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se aktualizovat kartičku.'));
    }
  }

  /// Statická pomocná metoda pro extrakci českého překladu z vysvětlení (např. z "(jeden měsíc)").
  static String? extractCzechFromExplanation(String explanation) {
    if (explanation.isEmpty) return null;
    final parensMatch = RegExp(r'\(([^)]{2,60})\)').firstMatch(explanation);
    if (parensMatch != null) {
      final candidate = parensMatch.group(1)?.trim() ?? '';
      final lower = candidate.toLowerCase();
      if (!lower.contains('minulý') &&
          !lower.contains('čas') &&
          !lower.contains('sloves') &&
          lower != 'noun' &&
          lower != 'verb' &&
          lower != 'adj' &&
          candidate.isNotEmpty) {
        return candidate.replaceAll('"', '').replaceAll("'", '').trim();
      }
    }
    return null;
  }

  /// Určuje, zda kartička obsahuje zastaralé či anglické zadání na líci.
  static bool isLegacyOrEnglishFront(String frontText, {String? backText, String? sourceSentence}) {
    final text = frontText.trim();
    if (text.isEmpty) return true;
    if (text == 'Přeložte do angličtiny správné vyjádření' || text == 'Přeložte do angličtiny') return true;
    if (text.startsWith('Jak ') || text.startsWith('Jak:') || text.startsWith('Přeložte') || text.startsWith('Opravte')) return true;
    // Pokud text obsahuje uvozovky a vnitřek odpovídá backText → legacy šablona s anglickým textem
    if ((text.contains('"') || text.contains('\u201c') || text.contains('\u201d'))) {
      final stripped = text.replaceAll(RegExp('[\u201c\u201d"]+'), '').trim();
      if (backText != null && stripped.toLowerCase() == backText.trim().toLowerCase()) return true;
      if (sourceSentence != null && stripped.toLowerCase() == sourceSentence.trim().toLowerCase()) return true;
    }
    if (backText != null && text.toLowerCase() == backText.trim().toLowerCase()) return true;
    if (sourceSentence != null && text.toLowerCase() == sourceSentence.trim().toLowerCase()) return true;

    // Detekce nesouladu délky mezi celou větou na líci a pouhou frází na rubu:
    // Pokud má backText nejvýše 3 slova, ale frontText má 5 a více slov
    // (např. "Nemůžu běhat protože mě bolí noha" vs "can't run"), jedná se o nekompletní kartičku.
    // Označíme ji, aby se frontText automaticky srovnal s backText ("can't run" -> "Nemůžu běhat").
    if (backText != null) {
      final backWords = backText.trim().split(RegExp(r'\s+')).length;
      final frontWords = text.split(RegExp(r'\s+')).length;
      if (backWords <= 3 && frontWords >= 5) {
        return true;
      }
    }

    return false;
  }

  /// Vytvoří kartičku přímo ze záznamu v historii/transkriptu a označí větu jako uloženou.
  Future<Result<int>> createFlashcardFromTranscript({
    required int transcriptId,
    required String userSaid,
    required String correctForm,
    required String explanation,
    String? czechPrompt,
    String errorType = 'grammar',
    int? errorLogId,
  }) async {
    try {
      String front = (czechPrompt != null && czechPrompt.trim().isNotEmpty)
          ? czechPrompt.trim()
          : '';

      if (front.isEmpty) {
        final extracted = extractCzechFromExplanation(explanation);
        front = (extracted != null && extracted.isNotEmpty)
            ? extracted
            : 'Přeložte do angličtiny';
      }

      final res = await addFlashcard(
        frontText: front,
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

  /// Odstraní neplatné kartičky vzniklé z halucinací AI (např. tutorovy monology, instrukce nebo příliš dlouhé texty).
  Future<int> cleanupInvalidFlashcards() async {
    try {
      final allCards = await getAllFlashcards();
      int deletedCount = 0;
      for (final card in allCards) {
        final lowerFront = card.frontText.toLowerCase();
        final lowerBack = card.backText.toLowerCase();
        final lowerSource = (card.sourceSentence ?? '').toLowerCase();

        final isInvalid = card.frontText.length > 140 ||
            card.backText.length > 140 ||
            lowerFront.contains('soustředit na naši') ||
            lowerFront.contains('nepřepínej') ||
            lowerFront.contains('as an ai') ||
            lowerFront.contains('translation task') ||
            lowerBack.contains('soustředit na naši') ||
            lowerBack.contains('how is your day') ||
            lowerSource.contains('soustředit na naši');

        if (isInvalid) {
          await deleteFlashcard(card.id);
          deletedCount++;
          L.i('Smazána neplatná kartička #${card.id}: "${card.frontText}" -> "${card.backText}"');
        }
      }
      if (deletedCount > 0) {
        L.i('Celkem vyčištěno $deletedCount neplatných kartiček.');
      }
      return deletedCount;
    } catch (e, stack) {
      L.e('Chyba při čištění neplatných kartiček', e, stack);
      return 0;
    }
  }

  /// Odstraní duplicitní kartičky (se stejným backText).
  /// Z každé skupiny duplicit zachová tu s nejlepším masteryScore (nejvíce pokročilou).
  /// Volá se jednorázově při migraci databáze.
  Future<int> removeDuplicateFlashcards() async {
    try {
      await cleanupInvalidFlashcards();
      final allCards = await getAllFlashcards();
      if (allCards.length <= 1) return 0;

      // Seskupení kartiček podle backText (case-insensitive)
      final groups = <String, List<Flashcard>>{};
      for (final card in allCards) {
        final key = card.backText.trim().toLowerCase();
        groups.putIfAbsent(key, () => []).add(card);
      }

      int removedCount = 0;
      for (final group in groups.values) {
        if (group.length <= 1) continue;

        // Seřadíme podle masteryScore sestupně — zachováme tu nejlepší
        group.sort((a, b) => b.masteryScore.compareTo(a.masteryScore));
        final keep = group.first;

        for (int i = 1; i < group.length; i++) {
          await (_db.delete(_db.flashcards)..where((t) => t.id.equals(group[i].id))).go();
          removedCount++;
        }

        L.i('Deduplikace: zachována kartička #${keep.id} (mastery=${keep.masteryScore}), smazáno ${group.length - 1} duplikátů pro "${keep.backText}".');
      }

      if (removedCount > 0) {
        L.i('Celkem odstraněno $removedCount duplicitních kartiček.');
      }
      return removedCount;
    } catch (e, stack) {
      L.e('Chyba při odstraňování duplicitních kartiček', e, stack);
      return 0;
    }
  }
}
