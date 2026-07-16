import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';
import 'scenario_planner_agent.dart';

class MemoryManagerAgent {
  final Ref _ref;

  MemoryManagerAgent(this._ref);

  Future<void> analyzeSession(int sessionId) async {
    debugPrint('Zahajuji analýzu session $sessionId pomocí Structured Outputs...');
    
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiAnalysisClientProvider);
    
    if (gemini == null) return;

    try {
      // 1. Načtení transkriptů
      final transcripts = await repo.getTranscripts(sessionId);
      L.i('Nalezeno ${transcripts.length} záznamů v transkriptu pro session $sessionId');
      
      if (transcripts.isEmpty) {
        L.w('Transkript je prázdný, analýza session $sessionId nebude provedena.');
        return;
      }

      final chatHistory = transcripts.map((t) => '${t.speaker}: ${t.content}').join('\n');
      final wrappedHistory = '<transcript>\n$chatHistory\n</transcript>';

      // 2. Analýza pomocí Gemini a JSON Schema
      L.i('Odesílám transkript k analýze do Gemini (Structured Outputs)...');
      final analysisResult = await gemini.sendMessage(
        wrappedHistory,
        responseSchema: SystemPromptBuilder.getAnalysisResponseSchema(),
      );
      L.i('Analýza od Gemini přijata.');
      
      final data = jsonDecode(analysisResult);

      // 3. Uložení výsledků
      L.i('Ukládám výsledky analýzy do databáze...');
      await repo.updateSessionAnalysis(
        sessionId: sessionId,
        topicSummary: data['topicSummary'] ?? 'Bez popisu',
        fluencyScore: (data['fluencyScore'] ?? 0.0).toDouble(),
        totalErrors: (data['totalErrors'] ?? 0).toInt(),
      );

      await repo.updateUserMemory(data['briefing'] ?? '');
      
      // Aktualizace odhadované úrovně angličtiny v profilu
      if (data['estimatedLevel'] != null) {
        final estLevel = data['estimatedLevel'].toString().toUpperCase();
        if (['A1', 'A2', 'B1', 'B2'].contains(estLevel)) {
          L.i('Agent odhadl úroveň studenta na: $estLevel. Aktualizuji profil.');
          await repo.updateTargetLevel(estLevel);
        }
      }
      
      // Uložení slovíček
      if (data['vocabulary'] != null && data['vocabulary'] is List) {
        final List<String> newWords = List<String>.from(data['vocabulary']);
        await repo.updateUserVocabulary(newWords);
      }

      // 4. Uložení jednotlivých chyb
      if (data['errors'] != null && data['errors'] is List) {
        for (var err in data['errors']) {
          await repo.addErrorLog(
            sessionId: sessionId,
            errorType: err['type'] ?? 'grammar',
            userSaid: err['userSaid'] ?? '',
            correctForm: err['correctForm'] ?? '',
            explanation: err['explanation'] ?? '',
          );
        }
      }
      
      debugPrint('Analýza session $sessionId dokončena přesně (JSON).');

      // 5. Spuštění plánování scénářů na příště
      _ref.read(scenarioPlannerAgentProvider).planScenarios();

    } catch (e) {
      debugPrint('Chyba při strukturované analýze session: $e');
    }
  }
}

final memoryManagerAgentProvider = Provider<MemoryManagerAgent>((ref) => MemoryManagerAgent(ref));
