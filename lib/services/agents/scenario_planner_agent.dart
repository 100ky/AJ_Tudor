import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../data/database/app_database.dart';
import '../prompt/system_prompt_builder.dart';

class ScenarioPlannerAgent {
  final Ref _ref;

  ScenarioPlannerAgent(this._ref);

  Future<void> planScenarios() async {
    debugPrint('Zahajuji plánování scénářů...');
    
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiBatchClientProvider); // Použijeme standardní chat klienta
    
    if (gemini == null) return;

    try {
      // 1. Načtení dat o uživateli
      final profile = await repo.getUserProfile();
      if (profile == null) return;

      // 2. Příprava promptu
      final prompt = SystemPromptBuilder.buildScenarioPlannerPrompt(
        userInterests: profile.topicPreferences,
        recentErrors: profile.recurringErrors,
        currentVocabulary: profile.vocabulary,
      );

      // 3. Generování pomocí Structured Outputs
      final result = await gemini.sendMessage(
        'Vygeneruj 3 nové scénáře na základě mého profilu.',
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getScenarioResponseSchema(),
      );

      final data = jsonDecode(result);

      // 4. Uložení do databáze
      if (data['scenarios'] != null && data['scenarios'] is List) {
        final List<Scenario> newScenarios = [];
        for (var s in data['scenarios']) {
          newScenarios.add(Scenario(
            id: 0, // Drift auto-increment
            externalId: s['id'] ?? 'unknown',
            title: s['title'] ?? 'Bez názvu',
            description: s['description'] ?? '',
            tutorInstruction: s['tutorInstruction'] ?? '',
            difficulty: s['difficulty'] ?? 'medium',
            isUsed: false,
            createdAt: DateTime.now(),
          ));
        }
        
        await repo.replaceScenarios(newScenarios);
        debugPrint('Generování scénářů dokončeno. Uloženy 3 nové možnosti.');
      }

    } catch (e) {
      debugPrint('Chyba při plánování scénářů: $e');
    }
  }
}

final scenarioPlannerAgentProvider = Provider<ScenarioPlannerAgent>((ref) => ScenarioPlannerAgent(ref));
