import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/error_handling.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../gemini/gemini_batch_client.dart';
import '../gemini/gemini_json.dart';
import '../prompt/task_prompts.dart';

/// Tvorba a údržba kartiček pomocí AI: kartičky z chyb studenta, překlad starých
/// anglických zadání do češtiny a nová slovíčka na míru studentovi.
class FlashcardGenerationService {
  final SessionRepository _sessions;
  final FlashcardRepository _flashcards;
  final ProfileRepository _profile;

  FlashcardGenerationService(this._sessions, this._flashcards, this._profile);

  /// Přeloží anglickou větu/frázi do přirozené češtiny pro líc kartičky.
  ///
  /// Vrátí null, pokud model nevrátil použitelný překlad; chyby volání propadají dál.
  static Future<String?> translateToCzech(GeminiBatchClient geminiClient, String english) async {
    final raw = await geminiClient.sendMessage(TaskPrompts.translateToCzech(english));
    final clean = raw.trim().replaceAll('"', '').replaceAll('\n', ' ');
    return (clean.isNotEmpty && !clean.startsWith('❌')) ? clean : null;
  }

  /// Automaticky vygeneruje nové kartičky z dosud nezpracovaných chyb studenta.
  /// 
  /// [sessionId] volitelné filtrování na konkrétní lekci.
  /// [limit] maximální počet kartiček vytvořených v jedné dávce (výchozí 15).
  /// [geminiClient] volitelný klient pro rychlý překlad do češtiny (zadání na líci).
  Future<Result<int>> generateFlashcardsFromErrors({
    int? sessionId,
    int limit = 15,
    GeminiBatchClient? geminiClient,
  }) async {
    try {
      // 1. Získáme dosud nezpracované chyby z databáze
      final allErrors = await _sessions.getErrorLogsWithoutFlashcard(sessionId: sessionId);
      if (allErrors.isEmpty) {
        return Result.success(0);
      }

      // 2. Načteme existující kartičky pro kontrolu duplicit (podle sourceSentence nebo backText)
      final existingCards = await _flashcards.getAllFlashcards();
      final existingBackTexts = existingCards.map((c) => c.backText.trim().toLowerCase()).toSet();
      final existingSources = existingCards.map((c) => (c.sourceSentence ?? '').trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
      final existingErrorLogIds = existingCards.map((c) => c.errorLogId).whereType<int>().toSet();

      int createdCount = 0;
      final seenNewPhrases = <String>{};

      for (final err in allErrors) {
        if (createdCount >= limit) break;

        final userSaid = err.userSaid.trim();
        final correctForm = err.correctForm.trim();
        if (userSaid.isEmpty || correctForm.isEmpty) {
          await _sessions.markErrorLogInFlashcard(err.id);
          continue;
        }

        final lowerSaid = userSaid.toLowerCase();
        final lowerCorrect = correctForm.toLowerCase();

        // Filtrování nesmyslných chyb (např. tutorovy monology, systémové hlášky nebo příliš dlouhé texty)
        if (correctForm.length > 120 ||
            userSaid.length > 150 ||
            lowerSaid == lowerCorrect ||
            lowerSaid.startsWith('hmm') ||
            lowerSaid.contains('wait a minute') ||
            lowerSaid.contains('translation task') ||
            lowerSaid.contains('my friend') ||
            lowerSaid.contains('soustředit na naši') ||
            lowerSaid.contains('nepřepínej') ||
            lowerSaid.contains('how is your day') ||
            lowerCorrect.contains('soustředit na naši') ||
            lowerSaid.contains('as an ai')) {
          await _sessions.markErrorLogInFlashcard(err.id);
          continue;
        }

        // Přeskočit pokud už tato fráze nebo chyba v kartičkách existuje
        if (existingErrorLogIds.contains(err.id) ||
            existingBackTexts.contains(lowerCorrect) ||
            existingSources.contains(lowerSaid) ||
            seenNewPhrases.contains(lowerCorrect)) {
          // Synchronizujeme inFlashcard příznak
          await _sessions.markErrorLogInFlashcard(err.id);
          continue;
        }

        seenNewPhrases.add(lowerCorrect);

        String targetWord = correctForm;
        String frontText = '';
        String? contextExample = (correctForm != userSaid && userSaid.isNotEmpty) ? correctForm : userSaid;

        // ZÁSADA ATOMICKÝCH KARTIČEK:
        // Pokud je correctForm celá dlouhá věta (> 3 slova), zkusíme z ní vydestilovat
        // cílové slovíčko nebo kolokaci, a celou větu zachováme jako kontextový příklad na rubu.
        final wordCount = correctForm.split(RegExp(r'\s+')).length;
        if (wordCount > 3 && geminiClient != null) {
          try {
            final prompt = TaskPrompts.extractTargetPhrase(
              correctForm: correctForm,
              userSaid: userSaid,
              explanation: err.explanation,
            );

            final response = await geminiClient.sendMessage(prompt);
            final dynamic decoded = decodeModelJson(response);
            if (decoded is Map) {
              final t = decoded['target']?.toString().trim();
              final c = decoded['czech']?.toString().trim();
              if (t != null && t.isNotEmpty && c != null && c.isNotEmpty) {
                targetWord = t;
                frontText = c;
                contextExample = correctForm;
              }
            }
          } catch (_) {}
        }

        if (frontText.isEmpty && geminiClient != null) {
          try {
            frontText = await translateToCzech(geminiClient, targetWord) ?? '';
          } catch (_) {}
        }

        if (frontText.isEmpty) {
          final extracted = FlashcardRepository.extractCzechFromExplanation(err.explanation);
          frontText = (extracted != null && extracted.isNotEmpty)
              ? extracted
              : 'Přeložte do angličtiny';
        }

        final cardRes = await _flashcards.addFlashcard(
          frontText: frontText,
          backText: targetWord,
          explanation: err.explanation.isNotEmpty ? err.explanation : 'Oprava chyby z konverzace',
          errorType: err.errorType,
          sourceSentence: contextExample,
          errorLogId: err.id,
        );

        if (cardRes.isSuccess) {
          createdCount++;
          await _sessions.markErrorLogInFlashcard(err.id);
        }
      }

      L.i('Úspěšně vygenerováno $createdCount kartiček z chyb.');
      return Result.success(createdCount);
    } catch (e, stack) {
      L.e('Chyba při hromadném generování kartiček z chyb', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se vygenerovat kartičky z chyb.'));
    }
  }

  /// Uloží opravu z chytré bubliny jako kartičku.
  ///
  /// Líc je český překlad [correctForm] přes [geminiClient]. Když se nepodaří,
  /// použije se česká část [explanation], jinak obecné zadání.
  Future<Result<int>> saveCorrection({
    required String correctForm,
    required String explanation,
    required String errorType,
    String? sourceSentence,
    GeminiBatchClient? geminiClient,
  }) async {
    String front = '';
    if (geminiClient != null) {
      try {
        front = await translateToCzech(geminiClient, correctForm) ?? '';
      } catch (_) {}
    }

    if (front.isEmpty) {
      final extracted = FlashcardRepository.extractCzechFromExplanation(explanation);
      front = (extracted != null && extracted.isNotEmpty)
          ? extracted
          : 'Přeložte do angličtiny';
    }

    return _flashcards.addFlashcard(
      frontText: front,
      backText: correctForm,
      explanation: explanation,
      errorType: errorType,
      sourceSentence: sourceSentence,
    );
  }

  /// Automaticky přeloží a opraví staré kartičky se zadáním v chybné angličtině do přirozené češtiny.
  Future<int> autoMigrateLegacyCardsToCzech(GeminiBatchClient geminiClient) async {
    try {
      final allCards = await _flashcards.getAllFlashcards();
      final legacyCards = allCards.where((c) {
        return FlashcardRepository.isLegacyOrEnglishFront(
          c.frontText,
          backText: c.backText,
          sourceSentence: c.sourceSentence,
        );
      }).toList();

      if (legacyCards.isEmpty) return 0;

      int migrated = 0;

      // Pokus o dávkový překlad všech starých kartiček v 1 rychlém JSON dotazu
      try {
        final batchList = legacyCards.map((c) => {
          'id': c.id,
          'english': c.backText,
        }).toList();

        final response = await geminiClient.sendMessage(
          TaskPrompts.batchTranslateCardsToCzech(batchList),
        );
        final dynamic decoded = decodeModelJson(response);
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map && item['id'] != null && item['czechPrompt'] != null) {
              final id = int.tryParse(item['id'].toString());
              final czech = item['czechPrompt'].toString().trim().replaceAll('"', '');
              if (id != null && czech.isNotEmpty && !czech.startsWith('❌')) {
                await _flashcards.updateFlashcardFrontText(id, czech);
                migrated++;
              }
            }
          }
        }
      } catch (batchErr) {
        L.w('Dávkový překlad kartiček selhal, zkouším jednotlivě: $batchErr');
      }

      // Pokud dávkový překlad selhal nebo nezpracoval vše, zpracujeme zbývající jednotlivě
      if (migrated < legacyCards.length) {
        final currentCards = await _flashcards.getAllFlashcards();
        final remainingCards = currentCards.where((c) {
          return FlashcardRepository.isLegacyOrEnglishFront(
            c.frontText,
            backText: c.backText,
            sourceSentence: c.sourceSentence,
          );
        }).toList();

        for (final card in remainingCards) {
          try {
            // Nejprve zkusíme okamžitou extrakci z vysvětlení
            final extracted = FlashcardRepository.extractCzechFromExplanation(card.explanation);
            if (extracted != null && extracted.isNotEmpty) {
              await _flashcards.updateFlashcardFrontText(card.id, extracted);
              migrated++;
              continue;
            }

            final czech = await translateToCzech(geminiClient, card.backText);
            if (czech != null) {
              await _flashcards.updateFlashcardFrontText(card.id, czech);
              migrated++;
            }
          } catch (e) {
            L.w('Chyba při migraci kartičky #${card.id}: $e');
          }
        }
      }

      if (migrated > 0) {
        L.i('Úspěšně migrováno $migrated starých kartiček na české zadání.');
      }
      return migrated;
    } catch (e, stack) {
      L.e('Chyba při migraci kartiček', e, stack);
      return 0;
    }
  }

  /// Vygeneruje sadu nových náhodných slovíček přizpůsobených úrovni a zájmům studenta.
  Future<Result<int>> generateRandomVocabularyCards({
    required GeminiBatchClient geminiClient,
    int count = 5,
  }) async {
    try {
      final user = await _profile.getUserProfile();
      final level = user?.targetLevel ?? 'B1';

      // Získáme fakta studenta ("O mně") pro personalizaci slovní zásoby
      final facts = await _profile.getUserFacts();
      final interests = facts.take(5).toList();

      // Získáme dosud existující kartičky pro kontrolu duplicit
      final existingCards = await _flashcards.getAllFlashcards();
      final existingWords = existingCards
          .map((c) => c.backText.trim().toLowerCase())
          .toSet();

      final responseText = await geminiClient.sendMessage(
        TaskPrompts.randomVocabulary(
          count: count,
          level: level,
          interests: interests,
          existingWords: existingWords,
        ),
      );
      final dynamic decoded = decodeModelJson(responseText);
      if (decoded is! List) {
        return Result.failure(ApiFailure('Neplatný formát odpovědi od AI.'));
      }

      int insertedCount = 0;
      for (var item in decoded) {
        if (item is Map) {
          final czech = item['czech']?.toString().trim() ?? '';
          final english = item['english']?.toString().trim() ?? '';
          final example = item['exampleSentence']?.toString().trim() ?? '';

          if (czech.isEmpty || english.isEmpty) continue;
          if (existingWords.contains(english.toLowerCase())) continue;

          await _flashcards.addFlashcard(
            frontText: czech,
            backText: english,
            explanation: example.isNotEmpty ? example : 'Užitečné slovíčko pro úroveň $level',
            errorType: 'vocabulary',
          );
          insertedCount++;
        }
      }

      L.i('Úspěšně vygenerováno $insertedCount náhodných slovíček do kartiček.');
      return Result.success(insertedCount);
    } catch (e, stack) {
      L.e('Chyba při generování náhodných slovíček', e, stack);
      return Result.failure(ApiFailure('Nepodařilo se vygenerovat nová slovíčka: $e'));
    }
  }
}

/// Poskytuje [FlashcardGenerationService] nad repozitáři aplikace.
final flashcardGenerationServiceProvider = Provider<FlashcardGenerationService>((ref) {
  return FlashcardGenerationService(
    ref.watch(sessionRepositoryProvider),
    ref.watch(flashcardRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  );
});
