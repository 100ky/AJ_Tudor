import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';

class MemoryManagerAgent {
  final Ref _ref;

  MemoryManagerAgent(this._ref);

  Future<void> analyzeSession(int sessionId) async {
    debugPrint('Zahajuji analýzu session $sessionId...');
    
    final repo = _ref.read(sessionRepositoryProvider);
    final gemini = _ref.read(geminiAnalysisClientProvider);
    
    if (gemini == null) return;

    try {
      // 1. Načtení transkriptů
      final transcripts = await repo.getTranscripts(sessionId);
      if (transcripts.isEmpty) return;

      final chatHistory = transcripts.map((t) => '${t.speaker}: ${t.content}').join('\n');

      // 2. Analýza pomocí Gemini Flash
      final prompt = '''Analyzuj tuto konverzaci mezi tutorem (AI) a studentem:
$chatHistory

Úkol:
1. Vygeneruj stručné shrnutí tématu (topicSummary).
2. Ohodnoť plynulost studenta od 0.0 do 1.0 (fluencyScore) na základě délky vět a plynulosti.
3. Vytvoř krátký briefing pro příští lekci (např. "Student má problém s předpřítomným časem, příště procvičit.").
4. Identifikuj konkrétní chyby (gramatika, slovní zásoba, výslovnost).
5. Extrahuje 3-5 nejdůležitějších nových slovíček nebo frází, které student použil nebo které by se měl naučit (vocabulary).

Odpověz POUZE ve formátu JSON:
{
  "topicSummary": "string",
  "fluencyScore": 0.85,
  "totalErrors": 2,
  "briefing": "string",
  "vocabulary": ["slovíčko1", "slovíčko2"],
  "errors": [
    {
      "type": "grammar|vocabulary|pronunciation",
      "userSaid": "originální věta studenta",
      "correctForm": "opravená verze",
      "explanation": "krátké české vysvětlení proč je to špatně"
    }
  ]
}''';

      final analysisResult = await gemini.sendMessage(prompt);
      
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
      
      debugPrint('Analýza session $sessionId dokončena. Briefing a ${data['totalErrors']} chyb uloženo.');
    } catch (e) {
      debugPrint('Chyba při analýze session: $e');
    }
  }
}

final memoryManagerAgentProvider = Provider<MemoryManagerAgent>((ref) => MemoryManagerAgent(ref));
