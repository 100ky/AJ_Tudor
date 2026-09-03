import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../core/utils/logger.dart';
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

  /// Spustí asynchronní analýzu ukončené lekce podle jejího ID.
  /// 
  /// 1. Načte transkripci rozhovoru (uživatel vs. tutor).
  /// 2. Odešle historii do Gemini s definovaným JSON schématem.
  /// 3. Aktualizuje uživatelský profil v databázi (skóre plynulosti, odhadnutou úroveň, paměťový briefing).
  /// 4. Uloží nově naučená slovíčka a podrobný log chyb.
  /// 5. Spustí plánovač scénářů [ScenarioPlannerAgent] pro přípravu témat na příští lekce.
  Future<void> analyzeSession(int sessionId) async {
    L.i('Zahajuji analýzu session $sessionId pomocí Structured Outputs...');
    
    // Načtení repozitáře pro přístup k databázi a batch klienta Gemini určeného pro analýzy.
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiAnalysisClientProvider);
    
    if (gemini == null) {
      L.e('Gemini Analysis Client není k dispozici (chybí API klíč). Analýza zrušena.');
      return;
    }

    try {
      // 1. Načtení historie transkriptu pro zadané sezení z databáze
      final transcripts = await repo.getTranscripts(sessionId);
      L.i('Nalezeno ${transcripts.length} záznamů v transkriptu pro session $sessionId');
      
      if (transcripts.isEmpty) {
        L.w('Transkript je prázdný, analýza session $sessionId nebude provedena.');
        return;
      }

      // Sestavení textové reprezentace rozhovoru zabalené do XML tagu pro lepší separaci dat
      final chatHistory = transcripts.map((t) => '${t.speaker}: ${t.content}').join('\n');
      final wrappedHistory = '<transcript>\n$chatHistory\n</transcript>';

      // Načtení předchozího profilu pro získání staršího briefingu (dlouhodobé paměti)
      final userProfile = await repo.getUserProfile();
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
        systemPrompt: SystemPromptBuilder.buildAnalysisPrompt(previousBriefing: previousBriefing),
        responseSchema: SystemPromptBuilder.getAnalysisResponseSchema(),
      );
      L.i('Analýza od Gemini úspěšně přijata.');
      
      // Dekódování strukturovaného JSON výsledku
      final data = jsonDecode(analysisResult);

      // --- BEZPEČNÉ PARSOVÁNÍ ČÍSEL ---
      double fluency = 0.0;
      if (data['fluencyScore'] != null) {
        fluency = double.tryParse(data['fluencyScore'].toString()) ?? 0.0;
      }
      
      int totalErr = 0;
      if (data['totalErrors'] != null) {
        totalErr = int.tryParse(data['totalErrors'].toString()) ?? 0;
      }

      // 3. Uložení globálních výsledků analýzy do databáze
      L.i('Ukládám výsledky analýzy do databáze...');
      await repo.updateSessionAnalysis(
        sessionId: sessionId,
        topicSummary: data['topicSummary']?.toString() ?? 'Bez popisu',
        fluencyScore: fluency,
        totalErrors: totalErr,
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
          await repo.pruneResolvedErrors(resolved); 
        }
      }

      // --- INTEGRACE FRUSTRACE A SEBE-REFLEXE ---
      // Uložení shrnutí/briefingu pro příští lekci do profilu studenta (pouze pokud nebyla lekce příliš krátká)
      if (!isTooShort) {
        String finalBriefing = data['briefing'] ?? '';
        final tutorFeedback = data['tutorFeedback'];
        
        // Zřetězení analytického briefingu s kritikou chování AI
        if (tutorFeedback != null && tutorFeedback.toString().isNotEmpty) {
           finalBriefing += '\n\nKRITICKÁ SEBE-REFLEXE (Self-Correction pro tutora na příště): $tutorFeedback';
        }
        
        // --- PREVENCE NAFUKOVÁNÍ PROMPTU ---
        // Analytik má tendenci nabalovat staré briefingy. Ořízneme briefing,
        // aby nepřekročil ~500-600 znaků a nestal se attention sinkem.
        if (finalBriefing.length > 600) {
           finalBriefing = '...${finalBriefing.substring(finalBriefing.length - 600)}';
        }
        
        await repo.updateUserMemory(finalBriefing);
      }
      
      // Aktualizace odhadované úrovně angličtiny v profilu studenta (pokud byla rozpoznána)
      if (data['estimatedLevel'] != null) {
        final estLevel = data['estimatedLevel'].toString().toUpperCase();
        if (['A1', 'A2', 'B1', 'B2'].contains(estLevel)) {
          L.i('Agent odhadl úroveň studenta na: $estLevel. Aktualizuji profil.');
          await repo.updateTargetLevel(estLevel);
        }
      }
      
      // Uložení nově zaznamenaných slovíček do databáze
      if (data['vocabulary'] != null && data['vocabulary'] is List) {
        final List<String> newWords = (data['vocabulary'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (newWords.isNotEmpty) {
          await repo.updateUserVocabulary(newWords);
        }
      }

      // 4. Uložení nově zjištěných osobních faktů o studentovi do profilu ("O mně")
      if (data['newLearnedUserFacts'] != null && data['newLearnedUserFacts'] is List) {
        final List<String> newFacts = (data['newLearnedUserFacts'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (newFacts.isNotEmpty) {
          await repo.updateUserFacts(newFacts);
          L.i('Uloženo ${newFacts.length} nových faktů o studentovi do "O mně": $newFacts');
        }
      }

      // 5. Uložení jednotlivých gramatických/výslovnostních chyb do detailního chybového logu a profilu
      if (data['errors'] != null && data['errors'] is List) {
        final List<String> newErrors = [];
        for (var err in data['errors']) {
          if (err is Map) {
            final type = err['type']?.toString() ?? 'grammar';
            final userSaid = err['userSaid']?.toString() ?? '';
            final correctForm = err['correctForm']?.toString() ?? '';
            final explanation = err['explanation']?.toString() ?? '';
            
            final errorLogRes = await repo.addErrorLog(
              sessionId: sessionId,
              errorType: type,
              userSaid: userSaid,
              correctForm: correctForm,
              explanation: explanation,
            );
            
            if (userSaid.isNotEmpty && correctForm.isNotEmpty) {
              newErrors.add('Řekl: "$userSaid", ale správně je: "$correctForm" ($explanation)');

              // Automatické vytvoření Smart Flashcard pro studenta
              await repo.addFlashcard(
                frontText: 'Jak opravit / říct: "$userSaid"?',
                backText: correctForm,
                explanation: explanation,
                errorType: type,
                sourceSentence: userSaid,
                errorLogId: errorLogRes.valueOrNull,
              );
            }
          }
        }
        
        if (newErrors.isNotEmpty) {
          await repo.updateUserRecurringErrors(newErrors);
          L.i('Přidáno ${newErrors.length} chyb do opakujících se chyb v profilu.');
        }
      }
      
      L.i('Analýza session $sessionId dokončena přesně (JSON).');

      // 6. Spuštění plánování nových scénářů na příště (asynchronně na pozadí)
      _ref.read(scenarioPlannerAgentProvider).planScenarios();

      // 7. Příprava nového konverzačního tématu pro příště z čerstvé historie
      _ref.read(topicPreparationAgentProvider.notifier).prepareTopic(force: true);

    } catch (e, stack) {
      L.e('Chyba při strukturované analýze session', e, stack);
    }
  }
}

/// Poskytuje globální instanci [MemoryManagerAgent] napříč aplikací.
final memoryManagerAgentProvider = Provider<MemoryManagerAgent>((ref) => MemoryManagerAgent(ref));
