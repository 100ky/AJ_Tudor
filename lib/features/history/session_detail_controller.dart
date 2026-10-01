import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../services/agents/memory_manager_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/flashcards/flashcard_generation_service.dart';
import '../../services/gemini/gemini_providers.dart';
import '../../services/prompt/task_prompts.dart';

/// Akce nad uloženou lekcí v historii: pokračování v textovém chatu,
/// kartičky z chyb, dodatečná analýza a smazání lekce.
class SessionDetailController {
  final Ref _ref;

  SessionDetailController(this._ref);

  /// Zda je nastavený API klíč, takže lze pokračovat v chatu nad lekcí.
  bool get canChat => _ref.read(geminiBatchClientProvider) != null;

  /// Pokračuje v textovém chatu nad lekcí.
  ///
  /// Uloží zprávu studenta (pak zavolá [onStudentMessageSaved]), zeptá se tutora
  /// s kontextem posledních 10 replik lekce a uloží jeho odpověď do přepisu.
  Future<void> sendFollowUp(
    Session session,
    String text, {
    void Function()? onStudentMessageSaved,
  }) async {
    final client = _ref.read(geminiBatchClientProvider);
    if (client == null) throw StateError('Chybí Gemini API klíč.');
    final repo = _ref.read(sessionRepositoryProvider);

    // 1. Uložit zprávu studenta do transkriptů
    await repo.addTranscript(
      sessionId: session.id,
      speaker: 'user',
      content: text,
    );
    onStudentMessageSaved?.call();

    // 2. Načíst kontext z předchozích zpráv této lekce
    final allTranscripts = await repo.getTranscripts(session.id);
    final recent = allTranscripts.length > 10
        ? allTranscripts.sublist(allTranscripts.length - 10)
        : allTranscripts;

    final conversationHistory = recent
        .map((t) => '${t.speaker == 'user' ? 'Student' : 'Tudor'}: ${t.content}')
        .join('\n');

    final profile = _ref.read(userProfileProvider).value;
    final targetLevel = profile?.targetLevel ?? 'B1';

    final reply = await client.sendMessage(TaskPrompts.sessionFollowUp(
      topic: session.topicSummary ?? 'Lekce angličtiny',
      targetLevel: targetLevel,
      conversationHistory: conversationHistory,
      message: text,
    ));

    // 3. Uložit odpověď tutora do transkriptů
    await repo.addTranscript(
      sessionId: session.id,
      speaker: 'tutor',
      content: reply.trim(),
    );
  }

  /// Vytvoří kartičky z dosud nezpracovaných chyb této lekce.
  Future<Result<int>> generateCards(int sessionId) {
    return _ref
        .read(flashcardGenerationServiceProvider)
        .generateFlashcardsFromErrors(sessionId: sessionId, limit: 15);
  }

  /// Spustí (opakovanou) analýzu lekce agentem paměti.
  Future<void> analyze(int sessionId) {
    return _ref.read(memoryManagerAgentProvider).analyzeSession(sessionId);
  }

  /// Vytvoří kartičku z chyby, kterou tutor opravil v dané replice.
  Future<Result<int>> addErrorToFlashcards(Transcript transcript, ErrorLog error) {
    return _ref.read(flashcardRepositoryProvider).createFlashcardFromTranscript(
          transcriptId: transcript.id,
          userSaid: error.userSaid,
          correctForm: error.correctForm,
          explanation: error.explanation,
          errorType: error.errorType,
          errorLogId: error.id,
        );
  }

  /// Smaže lekci. Po úspěchu přeplánuje scénáře, aby nenavazovaly na smazanou lekci.
  Future<Result<void>> deleteSession(int sessionId) async {
    final result = await _ref.read(sessionRepositoryProvider).deleteSession(sessionId);
    if (result.isSuccess) {
      _ref.read(scenarioPlannerAgentProvider).planScenarios();
    }
    return result;
  }
}

/// Poskytuje [SessionDetailController].
final sessionDetailControllerProvider =
    Provider<SessionDetailController>(SessionDetailController.new);
