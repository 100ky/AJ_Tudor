import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../prompt/system_prompt_builder.dart';

class MemoryManagerAgent {
  final Ref _ref;

  MemoryManagerAgent(this._ref);

  Future<void> analyzeSession(int sessionId) async {
    debugPrint('Zahajuji analýzu session $sessionId...');
    
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiBatchClientProvider);
    
    if (gemini == null) return;

    try {
      // 1. Načtení transkriptů
      final transcripts = await repo.getTranscripts(sessionId);
      if (transcripts.isEmpty) return;

      final chatHistory = transcripts.map((t) => '${t.speaker}: ${t.content}').join('\n');

      // 2. Analýza pomocí Gemini Flash
      final prompt = '''Analyzuj tuto konverzaci:
$chatHistory

Odpověz POUZE ve formátu JSON podle instrukcí v tvém systému.''';

      // Dočasně použijeme sendMessage, ale ideálně bychom měli mít čistý completion bez system promptu tutora.
      // Proto vytvoříme novou instanci modelu pro analýzu.
      final analysisResult = await gemini.sendMessage(prompt);
      
      // Pokus o parsování JSONu (Gemini občas přidá markdown tagy)
      final cleanJson = analysisResult.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(cleanJson);

      // 3. Uložení výsledků
      await repo.updateSessionAnalysis(
        sessionId: sessionId,
        topicSummary: data['topicSummary'] ?? 'Bez popisu',
        fluencyScore: (data['fluencyScore'] ?? 0.0).toDouble(),
        totalErrors: (data['totalErrors'] ?? 0).toInt(),
      );

      await repo.updateUserMemory(data['briefing'] ?? '');
      
      debugPrint('Analýza session $sessionId dokončena. Briefing uložen.');
    } catch (e) {
      debugPrint('Chyba při analýze session: $e');
    }
  }
}

final memoryManagerAgentProvider = Provider<MemoryManagerAgent>((ref) => MemoryManagerAgent(ref));
