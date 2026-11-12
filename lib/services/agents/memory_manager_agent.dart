import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../gemini/gemini_batch_client.dart';
import '../system/wakelock_service.dart';
import '../gemini/gemini_providers.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../../core/utils/logger.dart';
import '../../data/models/error_category.dart';
import '../flashcards/conversation_cards.dart';
import '../prompt/system_prompt_builder.dart';
import 'scenario_planner_agent.dart';
import 'topic_preparation_agent.dart';

/// Agent zodpovědný za správu dlouhodobé paměti a analýzu ukončených lekcí.
/// 
/// Po dokončení lekce (audio sezení) tento agent načte transkripty z databáze,
/// odešle je k analýze do Gemini (pomocí Structured Outputs s JSON schématem)
/// a získá vyhodnocení (plynulost, chyby, nová slovíčka, briefing pro příště atd.).
/// Následně tyto informace uloží zpět do lokální databáze a vyvolá plánovač scénářů.
class MemoryManagerAgent {
  /// Reference na Riverpod kontejner pro přístup k dalším službám a providerům.
  final Ref _ref;

  /// Inicializuje agenta paměti.
  MemoryManagerAgent(this._ref);

  /// Klíč v nastavení aplikace se seznamem lekcí, jejichž rozbor nedoběhl.
  static const String unfinishedAnalysesKey = 'unfinished_analyses';

  // Lekce, jejichž rozbor nedoběhl: chyběla mu síť, nebo se aplikace ukončila dřív, než
  // skončil. Seznam je uložený v nastavení aplikace, takže přežije i její ukončení (dřív
  // byl jen v paměti a lekce zůstala bez rozboru, dokud ho student nespustil ručně).
  Set<int>? _unfinishedLoaded;

  Set<int> get _unfinished {
    final loaded = _unfinishedLoaded;
    if (loaded != null) return loaded;
    final saved = _ref.read(sharedPreferencesProvider).getStringList(unfinishedAnalysesKey) ?? const <String>[];
    return _unfinishedLoaded = saved.map(int.tryParse).whereType<int>().toSet();
  }

  /// Zapíše, jestli rozbor lekce [sessionId] ještě čeká na dokončení.
  void _setUnfinished(int sessionId, bool unfinished) {
    final changed = unfinished ? _unfinished.add(sessionId) : _unfinished.remove(sessionId);
    if (!changed) return;
    _ref
        .read(sharedPreferencesProvider)
        .setStringList(unfinishedAnalysesKey, [for (final id in _unfinished) '$id']);
  }

  /// Lekce, jejichž rozbor nedoběhl. Zopakuje se po návratu do aplikace nebo po jejím
  /// dalším spuštění.
  ///
  /// Rozboru buď chyběla síť (9. 11.: displej zhasl pět vteřin po hovoru a systém aplikaci
  /// na pozadí odpojil), nebo se aplikace ukončila uprostřed něj (11. 11.: lekce 27 zůstala
  /// bez rozboru, protože aplikace skončila osm vteřin po hovoru). Rozbor, který selhal
  /// z jiného důvodu, se sám neopakuje. Rozbor, který právě běží, v seznamu není.
  List<int> get unfinishedAnalyses =>
      List.unmodifiable([for (final id in _unfinished) if (!_running.containsKey(id)) id]);

  /// Nejvyšší délka briefingu pro příští lekci (bez kritiky tutora).
  static const int maxBriefingChars = 600;

  /// Nejvyšší délka kritiky tutora připojené za briefing.
  static const int maxTutorFeedbackChars = 300;

  /// Kolik kartiček nejvýš vznikne z jedné lekce (z chyb i z výrazů, na které se student
  /// zeptal). Rozbor řadí chyby od nejdůležitější, takže zbytek se zapíše jen do logu chyb.
  static const int maxNewCardsPerLesson = 6;

  static final RegExp _word = RegExp(r"[\p{L}\p{N}']+", unicode: true);

  /// Počet slov v [text] (pro podíl řeči studenta a tutora).
  static int countWords(String text) => _word.allMatches(text).length;

  /// Kolik slov musí student v lekci říct, aby se z ní odhadovala úroveň. Lekce 23 měla
  /// 58 slov (hlavně zopakované věty) a úroveň v profilu spadla z ní na A2.
  static const int minWordsForLevel = 150;

  /// Z kolika posledních lekcí se bere ustálená úroveň.
  static const int levelWindow = 5;

  /// Ustálená úroveň z odhadů posledních lekcí [recentNewestFirst]: nejčastější, při
  /// shodě ta novější. Úroveň v profilu dřív skákala mezi A2 a B1 podle jedné lekce
  /// a tutor pokaždé měnil styl.
  static String? stableLevel(List<String> recentNewestFirst) {
    if (recentNewestFirst.isEmpty) return null;
    final counts = <String, int>{};
    for (final level in recentNewestFirst) {
      counts[level] = (counts[level] ?? 0) + 1;
    }
    var best = recentNewestFirst.first;
    for (final level in recentNewestFirst) {
      if (counts[level]! > counts[best]!) best = level;
    }
    return best;
  }

  /// Jemnější úroveň z rozboru; jen když sedí k hrubé úrovni (B1- k B1), jinak hrubá úroveň.
  static String _levelDetail(Object? detail, String level) {
    final value = detail?.toString().trim().toUpperCase().replaceAll('−', '-') ?? '';
    return value.startsWith(level) && value.length <= 3 ? value : level;
  }

  /// Zda je cíl kartičky krátký výraz, ne celá věta (tu by student doslova nezopakoval).
  static bool isAtomicCardTarget(String target) {
    final words = ConversationCards.normalize(target).split(' ').where((w) => w.isNotEmpty);
    return words.isNotEmpty && words.length <= ConversationCards.maxTargetWords;
  }

  /// Zkrátí [text] na nejvýš [max] znaků, pokud to jde, za koncem věty.
  static String clipBriefing(String text, int max) {
    final trimmed = text.trim();
    if (trimmed.length <= max) return trimmed;
    final head = trimmed.substring(0, max);
    final sentenceEnd = head.lastIndexOf(RegExp(r'[.!?](\s|$)'));
    if (sentenceEnd >= max ~/ 2) return head.substring(0, sentenceEnd + 1);
    return '${head.trimRight()}…';
  }

  /// Znaky, které se v angličtině ani češtině nevyskytují: španělské ¿ ¡ ñ
  /// a nelatinková písma (azbuka, hindština, arabština, japonština, čínština…).
  /// STT Gemini Live občas přepíše anglickou řeč studenta do cizího jazyka.
  static final _foreignTranscriptChars = RegExp(r'[¿¡ñÑͰ-᷿⺀-￯]');

  /// Spustí asynchronní analýzu ukončené lekce podle jejího ID.
  /// 
  /// 1. Načte transkripci rozhovoru (uživatel vs. tutor).
  /// 2. Odešle historii do Gemini s definovaným JSON schématem.
  /// 3. Aktualizuje uživatelský profil v databázi (skóre plynulosti, odhadnutou úroveň, paměťový briefing).
  /// 4. Uloží nově naučená slovíčka a podrobný log chyb.
  /// 5. Spustí plánovač scénářů [ScenarioPlannerAgent] pro přípravu témat na příští lekce.
  ///
  /// Během rozboru displej nezhasne, jinak systém aplikaci odpojí od sítě. Probíhající
  /// rozbor téže lekce se nespouští znovu, volající počká na jeho výsledek. Vrátí, zda se
  /// rozbor uložil.
  Future<bool> analyzeSession(int sessionId) {
    final running = _running[sessionId];
    if (running != null) {
      L.i('Rozbor lekce $sessionId už běží, počkám na jeho výsledek.');
      return running;
    }
    final analysis = _analyzeWithScreenOn(sessionId);
    _running[sessionId] = analysis;
    return analysis.whenComplete(() => _running.remove(sessionId));
  }

  // Probíhající rozbory podle lekce. 9. 11. se ruční „Analyzovat“ sešlo s automatickým
  // opakováním: dva rozbory jedné lekce uložily 12 chyb a 10 kartiček.
  final Map<int, Future<bool>> _running = {};

  Future<bool> _analyzeWithScreenOn(int sessionId) async {
    final wakelock = _ref.read(wakelockServiceProvider);
    final holder = 'rozbor lekce $sessionId';
    wakelock.enable(holder);
    try {
      return await _analyzeSession(sessionId);
    } finally {
      wakelock.disable(holder);
    }
  }

  Future<bool> _analyzeSession(int sessionId) async {
    L.i('Zahajuji analýzu session $sessionId pomocí Structured Outputs...');

    // Načtení repozitáře pro přístup k databázi a batch klienta Gemini určeného pro analýzy.
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final profileRepo = _ref.read(profileRepositoryProvider);
    final gemini = _ref.read(geminiAnalysisClientProvider);

    if (gemini == null) {
      L.e('Gemini Analysis Client není k dispozici (chybí API klíč). Analýza zrušena.');
      _setUnfinished(sessionId, false);
      return false;
    }

    // Rozbor je od teď rozdělaný. Když aplikace skončí dřív, než doběhne, zůstane
    // v seznamu a zopakuje se po dalším spuštění.
    _setUnfinished(sessionId, true);
    var retryLater = false;

    try {
      // 1. Načtení historie transkriptu pro zadané sezení z databáze
      final transcripts = await sessionRepo.getTranscripts(sessionId);
      L.i('Nalezeno ${transcripts.length} záznamů v transkriptu pro session $sessionId');
      
      if (transcripts.isEmpty) {
        L.w('Transkript je prázdný, analýza session $sessionId nebude provedena.');
        return false;
      }

      // Podíl řeči: student má mluvit aspoň polovinu, rozbor to tutorovi připomene
      final studentWords = transcripts.where((t) => t.speaker == 'user').fold(0, (sum, t) => sum + countWords(t.content));
      final tutorWords = transcripts.where((t) => t.speaker != 'user').fold(0, (sum, t) => sum + countWords(t.content));
      await sessionRepo.updateSessionWordCounts(
        sessionId: sessionId,
        studentWords: studentWords,
        tutorWords: tutorWords,
        studentReplies: transcripts.where((t) => t.speaker == 'user').length,
      );
      final studentShare = studentWords + tutorWords == 0 ? null : studentWords / (studentWords + tutorWords);
      if (studentShare != null) {
        L.i('Podíl řeči: student ${(studentShare * 100).round()} % ($studentWords slov), tutor $tutorWords slov.');
      }

      // Sestavení textové reprezentace rozhovoru zabalené do XML tagu pro lepší separaci dat
      final chatHistory = transcripts.map((t) => '${t.speaker}: ${t.content}').join('\n');
      final wrappedHistory = '<transcript>\n$chatHistory\n</transcript>';

      // Načtení předchozího profilu pro získání staršího briefingu (dlouhodobé paměti)
      final userProfile = await profileRepo.getUserProfile();
      final previousBriefing = userProfile?.memoryBriefing;
      
      // Zjistíme, zda byla lekce příliš krátká (méně než 2 zprávy od uživatele)
      final userMessagesCount = transcripts.where((t) => t.speaker == 'user').length;
      final isTooShort = userMessagesCount < 2;
      
      if (isTooShort) {
        L.i('Session $sessionId byla příliš krátká ($userMessagesCount replik uživatele). Dlouhodobý briefing nebudeme přepisovat.');
      }

      // 2. Analýza textu pomocí Gemini a vynucení strukturovaného výstupu (JSON Schema)
      L.i('Odesílám transkript k analýze do Gemini (Structured Outputs)...');
      final analysisResult = await gemini.sendMessage(
        wrappedHistory,
        systemPrompt: SystemPromptBuilder.buildAnalysisPrompt(
          previousBriefing: previousBriefing,
          knownFacts: userProfile?.userFacts,
          studentShare: studentShare,
        ),
        responseSchema: SystemPromptBuilder.getAnalysisResponseSchema(),
      );
      L.i('Analýza od Gemini úspěšně přijata.');
      
      // Dekódování strukturovaného JSON výsledku
      final data = jsonDecode(analysisResult);

      // Starý rozbor se smaže a nový zapíše v jedné transakci. Když zápis uprostřed selže
      // (třeba na nečekaném tvaru odpovědi), zůstane lekci předchozí rozbor celý. Dřív po
      // takové chybě zbyl smazaný starý rozbor a půlka nového.
      await _ref.read(databaseProvider).transaction(
            () => _saveAnalysis(sessionId, data, studentWords: studentWords, isTooShort: isTooShort),
          );

      L.i('Analýza session $sessionId dokončena přesně (JSON).');

      // 6. Spuštění plánování nových scénářů na příště (asynchronně na pozadí)
      _ref.read(scenarioPlannerAgentProvider).planScenarios();

      // 7. Příprava nového konverzačního tématu pro příště z čerstvé historie
      _ref.read(topicPreparationAgentProvider.notifier).prepareTopic(force: true, resetCounter: true);
      return true;
    } on GeminiNetworkException {
      retryLater = true;
      L.w('Rozbor lekce $sessionId selhal bez sítě, zopakuje se po návratu do aplikace.');
      return false;
    } catch (e, stack) {
      L.e('Chyba při strukturované analýze session', e, stack);
      return false;
    } finally {
      // Hotový rozbor i rozbor, který selhal jinak než na síti, se už sám neopakuje
      if (!retryLater) _setUnfinished(sessionId, false);
    }
  }

  /// Zapíše výsledek rozboru [data] lekce [sessionId] do databáze: nahradí předchozí rozbor,
  /// uloží hodnocení lekce, chyby a kartičky z nich a upraví profil studenta.
  ///
  /// Volá se uvnitř jedné transakce ([_analyzeSession]), výjimka tedy vrátí všechno zpět.
  Future<void> _saveAnalysis(
    int sessionId,
    dynamic data, {
    required int studentWords,
    required bool isTooShort,
  }) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final profileRepo = _ref.read(profileRepositoryProvider);
    final flashcardRepo = _ref.read(flashcardRepositoryProvider);

    // Nový rozbor nahradí předchozí. Jinak opakovaný rozbor zdvojil chyby i kartičky (9. 11.)
    final previous = await sessionRepo.clearSessionAnalysis(sessionId);
    if (previous.errors > 0) {
      L.i('Nahrazuji předchozí rozbor lekce $sessionId: smazáno ${previous.errors} chyb '
          'a ${previous.cards} neprocvičených kartiček.');
    }

    // --- BEZPEČNÉ PARSOVÁNÍ ČÍSEL ---
    double fluency = 0.0;
    if (data['fluencyScore'] != null) {
      fluency = double.tryParse(data['fluencyScore'].toString()) ?? 0.0;
    }

    int totalErr = 0;
    if (data['totalErrors'] != null) {
      totalErr = int.tryParse(data['totalErrors'].toString()) ?? 0;
    }

    // ─── STRUKTUROVANÝ VÝPIS VÝSLEDKŮ ANALÝZY ───
    final analysisLines = StringBuffer();
    analysisLines.writeln('Plynulost: ${fluency.toStringAsFixed(2)} | Úroveň: ${data['estimatedLevel'] ?? '?'} | Chyby: $totalErr');
    analysisLines.writeln('Shrnutí: ${data['topicSummary'] ?? 'Bez popisu'}');
    if (data['briefing'] != null && data['briefing'].toString().isNotEmpty) {
      analysisLines.writeln('Briefing pro příště: ${L.truncate(data['briefing'].toString(), 300)}');
    }
    if (data['tutorFeedback'] != null && data['tutorFeedback'].toString().isNotEmpty) {
      analysisLines.writeln('⚠️ Tutor Feedback (sebe-reflexe): ${data['tutorFeedback']}');
    }
    if (data['resolvedErrors'] != null && (data['resolvedErrors'] as List).isNotEmpty) {
      analysisLines.writeln('✅ Resolved Errors (Memory Pruning): ${(data['resolvedErrors'] as List).join(', ')}');
    }
    if (data['vocabulary'] != null && (data['vocabulary'] as List).isNotEmpty) {
      analysisLines.writeln('📖 Nová slovíčka: ${(data['vocabulary'] as List).join(', ')}');
    }
    if (data['newLearnedUserFacts'] != null && (data['newLearnedUserFacts'] as List).isNotEmpty) {
      analysisLines.writeln('🧑 Nové fakty o studentovi: ${(data['newLearnedUserFacts'] as List).join(', ')}');
    }
    L.block('ANALYSIS', 'Výsledky Gemini analýzy (session $sessionId)', analysisLines.toString());

    // Výpis jednotlivých chyb s kartičkami
    if (data['errors'] != null && (data['errors'] as List).isNotEmpty) {
      final errorItems = <String>[];
      for (var err in data['errors']) {
        if (err is Map) {
          final userSaid = err['userSaid']?.toString() ?? '';
          final correctForm = err['correctForm']?.toString() ?? '';
          final czechTranslation = err['czechTranslation']?.toString() ?? '';
          errorItems.add('"$userSaid" → "$correctForm" (CZ: $czechTranslation)');
        }
      }
      L.blockList('ANALYSIS', 'Kartičky z chyb', errorItems);
    }
    final estimatedLevel = data['estimatedLevel']?.toString().toUpperCase();
    // Krátká lekce nebo lekce, kde student skoro jen opakoval, o úrovni nic neříká
    final isKnownLevel = ['A1', 'A2', 'B1', 'B2'].contains(estimatedLevel) && studentWords >= minWordsForLevel;
    await sessionRepo.updateSessionAnalysis(
      sessionId: sessionId,
      topicSummary: data['topicSummary']?.toString() ?? 'Bez popisu',
      fluencyScore: fluency,
      totalErrors: totalErr,
      estimatedLevel: isKnownLevel && !isTooShort ? estimatedLevel : null,
      levelDetail: isKnownLevel && !isTooShort ? _levelDetail(data['levelDetail'], estimatedLevel!) : null,
      levelReason: isKnownLevel && !isTooShort ? data['levelReason']?.toString().trim() : null,
    );

    // --- ALGORITMUS ODNAUČOVÁNÍ (Memory Pruning) ---
    // Extrahujeme seznam chyb, které student přestal opakovat.
    if (data['resolvedErrors'] != null && data['resolvedErrors'] is List) {
      // Bezpečné parsování pouze stringů z pole
      final List<String> resolved = (data['resolvedErrors'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      if (resolved.isNotEmpty) {
        L.i('Detekováno zlepšení studenta. Aplikuji Memory Pruning a prořezávám chyby: $resolved');

        // Repozitář provede vyhledání a odstranění těchto jevů z opakujících se chyb,
        // čímž se efektivně uvolní kapacita kontextového okna a zabrání zacyklení
        await profileRepo.pruneResolvedErrors(resolved); 
      }
    }

    // --- INTEGRACE FRUSTRACE A SEBE-REFLEXE ---
    // Uložení shrnutí/briefingu pro příští lekci do profilu studenta (pouze pokud nebyla lekce příliš krátká)
    if (!isTooShort) {
      // --- PREVENCE NAFUKOVÁNÍ PROMPTU ---
      // Analytik má tendenci nabalovat staré briefingy, proto má briefing i kritika tutora
      // svůj limit. Zachová se začátek briefingu (slabiny a téma na příště): dřív se nechával
      // konec, takže z briefingu zbyla hlavně připojená kritika tutora.
      var finalBriefing = clipBriefing(data['briefing']?.toString() ?? '', maxBriefingChars);
      final tutorFeedback = data['tutorFeedback']?.toString() ?? '';

      // Zřetězení analytického briefingu s kritikou chování AI
      if (tutorFeedback.isNotEmpty) {
        finalBriefing += '\n\nKRITICKÁ SEBE-REFLEXE (Self-Correction pro tutora na příště): '
            '${clipBriefing(tutorFeedback, maxTutorFeedbackChars)}';
      }

      await profileRepo.updateUserMemory(finalBriefing);
    }

    // Úroveň v profilu: nejčastější odhad z posledních lekcí, ne jen z této
    if (isKnownLevel && !isTooShort) {
      final recent = await sessionRepo.getRecentEstimatedLevels(limit: levelWindow, minStudentWords: minWordsForLevel);
      final level = stableLevel(recent) ?? estimatedLevel!;
      L.i('Rozbor odhadl úroveň $estimatedLevel, z posledních lekcí (${recent.join(', ')}) platí $level.');
      await profileRepo.updateTargetLevel(level);
    }

    // Uložení nově zaznamenaných slovíček do databáze
    if (data['vocabulary'] != null && data['vocabulary'] is List) {
      final List<String> newWords = (data['vocabulary'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (newWords.isNotEmpty) {
        await profileRepo.updateUserVocabulary(newWords);
      }
    }

    // 4. Uložení nově zjištěných osobních faktů o studentovi do profilu ("O mně")
    if (data['newLearnedUserFacts'] != null && data['newLearnedUserFacts'] is List) {
      final List<String> newFacts = (data['newLearnedUserFacts'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (newFacts.isNotEmpty) {
        await profileRepo.updateUserFacts(newFacts);
        L.i('Uloženo ${newFacts.length} nových faktů o studentovi do "O mně": $newFacts');
      }
    }

    // 5. Uložení jednotlivých gramatických/výslovnostních chyb do detailního chybového logu a profilu
    if (data['errors'] != null && data['errors'] is List) {
      final List<String> newErrors = [];
      var cardsCreated = 0;
      for (var err in data['errors']) {
        if (err is Map) {
          final type = err['type']?.toString() ?? 'grammar';
          final userSaid = err['userSaid']?.toString().trim() ?? '';
          final correctForm = err['correctForm']?.toString().trim() ?? '';
          final explanation = err['explanation']?.toString().trim() ?? '';
          final targetWordOrPhrase = err['targetWordOrPhrase']?.toString().trim();
          final czechCue = err['czechCue']?.toString().trim();

          // FILTRACE LEAKŮ A SYSTÉMOVÝCH HLÁŠEK:
          // Tutorovy repliky, instrukce nebo příliš dlouhé texty nesmí proniknout do chyb ani kartiček
          final lowerSaid = userSaid.toLowerCase();
          final lowerCorrect = correctForm.toLowerCase();
          if (userSaid.isEmpty ||
              correctForm.isEmpty ||
              userSaid.length > 200 ||
              lowerSaid.contains('soustředit na naši') ||
              lowerSaid.contains('nepřepínej') ||
              lowerSaid.contains('how is your day') ||
              lowerSaid.contains('as an ai') ||
              lowerSaid.contains('translation task') ||
              lowerCorrect.contains('soustředit na naši')) {
            L.w('Filtrován neplatný záznam chyby (leaked tutor/system message): "$userSaid"');
            continue;
          }

          // Přepis v cizím jazyce je chyba STT, ne chyba studenta
          if (_foreignTranscriptChars.hasMatch(userSaid)) {
            L.w('Filtrován záznam chyby s přepisem v cizím jazyce (chyba STT): "$userSaid"');
            continue;
          }

          final errorLogRes = await sessionRepo.addErrorLog(
            sessionId: sessionId,
            errorType: type,
            userSaid: userSaid,
            correctForm: correctForm,
            explanation: explanation,
            category: ErrorCategory.parse(err['category']?.toString())?.id,
          );

          newErrors.add('Řekl: "$userSaid", ale správně je: "$correctForm" ($explanation)');

          final czechTranslation = err['czechTranslation']?.toString().trim();
          final extracted = FlashcardRepository.extractCzechFromExplanation(explanation);

          // Cílové slovíčko pro rub kartičky (atomická jednotka)
          final cardBack = (targetWordOrPhrase != null && targetWordOrPhrase.isNotEmpty)
              ? targetWordOrPhrase
              : correctForm;

          // České zadání pro líc kartičky (atomická jednotka)
          final cardFront = (czechCue != null && czechCue.isNotEmpty)
              ? czechCue
              : ((czechTranslation != null && czechTranslation.isNotEmpty)
                  ? czechTranslation
                  : (extracted != null && extracted.isNotEmpty ? extracted : 'Přeložte do angličtiny'));

          // Celá opravená věta slouží jako příklad a kontext na rubu kartičky
          final contextExample = (correctForm.isNotEmpty && correctForm.toLowerCase() != cardBack.toLowerCase())
              ? correctForm
              : (userSaid.isNotEmpty ? userSaid : null);

          if (cardsCreated >= maxNewCardsPerLesson) {
            L.i('Kartička "$cardBack" nevznikla: z lekce už je $maxNewCardsPerLesson kartiček.');
            continue;
          }
          if (!isAtomicCardTarget(cardBack)) {
            L.w('Kartička "$cardBack" nevznikla: cíl má víc než ${ConversationCards.maxTargetWords} slova.');
            continue;
          }

          // Automatické vytvoření Smart Flashcard pro studenta v češtině k procvičení
          await flashcardRepo.addFlashcard(
            frontText: cardFront,
            backText: cardBack,
            explanation: explanation,
            errorType: type,
            sourceSentence: contextExample,
            errorLogId: errorLogRes.valueOrNull,
          );
          cardsCreated++;
        }
      }

      if (newErrors.isNotEmpty) {
        await profileRepo.updateUserRecurringErrors(newErrors);
        L.i('Přidáno ${newErrors.length} chyb do opakujících se chyb v profilu.');
      }
    }
  }
}

/// Poskytuje globální instanci [MemoryManagerAgent] napříč aplikací.
final memoryManagerAgentProvider = Provider<MemoryManagerAgent>((ref) => MemoryManagerAgent(ref));
