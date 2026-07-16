import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../data/database/app_database.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';

/// Agent odpovědný za plánování a generování personalizovaných konverzačních scénářů.
/// 
/// Na základě profilu studenta (zájmy, opakující se gramatické chyby, aktuální slovní zásoba,
/// cílová úroveň angličtiny a briefing z minulých lekcí) generuje v dávkovém režimu
/// 3 nové konverzační scénáře (role-play), které uloží do databáze jako dostupné lekce pro uživatele.
class ScenarioPlannerAgent {
  /// Reference na Riverpod kontejner pro přístup ke službám a repozitářům.
  final Ref _ref;

  /// Inicializuje plánovače scénářů.
  ScenarioPlannerAgent(this._ref);

  /// Spustí proces plánování nových personalizovaných scénářů pro studenta.
  /// 
  /// Metoda načte aktuální data profilu studenta, sestaví specifický prompt pro Gemini,
  /// odešle dotaz na Gemini Batch Client s vynuceným JSON schématem a získané scénáře
  /// uloží do databáze (předchozí nevyužité scénáře jsou nahrazeny novými).
  Future<void> planScenarios() async {
    L.i('Zahajuji plánování scénářů...');
    
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiBatchClientProvider);
    
    if (gemini == null) {
      L.e('Gemini Batch Client není k dispozici (chybí API klíč). Generování scénářů zrušeno.');
      return;
    }

    try {
      // 1. Načtení aktuálního profilu uživatele z databáze
      final profile = await repo.getUserProfile();
      if (profile == null) {
        L.w('Uživatelský profil nebyl nalezen, plánování scénářů nelze spustit.');
        return;
      }

      // 2. Příprava promptu s parametry uživatele
      final prompt = SystemPromptBuilder.buildScenarioPlannerPrompt(
        userInterests: profile.topicPreferences,
        recentErrors: profile.recurringErrors,
        currentVocabulary: profile.vocabulary,
        targetLevel: profile.targetLevel,
        memoryBriefing: profile.memoryBriefing,
      );

      // 3. Odeslání dotazu a generování pomocí Structured Outputs (JSON Schema)
      final result = await gemini.sendMessage(
        'Vygeneruj 3 nové scénáře na základě mého profilu.',
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getScenarioResponseSchema(),
      );

      // Dekódování strukturovaného JSON výsledku
      final data = jsonDecode(result);

      // 4. Parsování a uložení nově vygenerovaných scénářů do databáze
      if (data['scenarios'] != null && data['scenarios'] is List) {
        final List<Scenario> newScenarios = [];
        for (var s in data['scenarios']) {
          newScenarios.add(Scenario(
            id: 0, // Drift databáze automaticky přiřadí auto-increment ID
            externalId: s['id'] ?? 'unknown',
            title: s['title'] ?? 'Bez názvu',
            description: s['description'] ?? '',
            tutorInstruction: s['tutorInstruction'] ?? '',
            difficulty: s['difficulty'] ?? 'medium',
            isUsed: false,
            createdAt: DateTime.now(),
          ));
        }
        
        // Přepsání starých nepoužitých scénářů v databázi novými personalizovanými scénáři
        await repo.replaceScenarios(newScenarios);
        L.i('Generování scénářů dokončeno. Uloženy 3 nové možnosti.');
      }

    } catch (e, stack) {
      L.e('Chyba při plánování scénářů', e, stack);
    }
  }
}

/// Poskytuje globální instanci [ScenarioPlannerAgent] napříč aplikací.
final scenarioPlannerAgentProvider = Provider<ScenarioPlannerAgent>((ref) => ScenarioPlannerAgent(ref));
