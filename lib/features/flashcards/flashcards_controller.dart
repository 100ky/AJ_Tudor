import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/result.dart';
import '../../data/data_providers.dart';
import '../../data/database/app_database.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/flashcards/flashcard_generation_service.dart';
import '../../services/gemini/gemini_batch_client.dart';
import '../../services/gemini/gemini_providers.dart';
import '../../services/gemini/gemini_tts_service.dart';
import '../../services/gemini/pronunciation_service.dart';
import 'answer_recorder.dart';
import 'card_front_resolver.dart';

/// Akce cvičebny kartiček: údržba balíčku, hodnocení, mazání, výslovnost a TTS.
class FlashcardsController {
  final Ref _ref;

  FlashcardsController(this._ref);

  /// Aktuální Gemini klient (null bez API klíče).
  GeminiBatchClient? get gemini => _ref.read(geminiBatchClientProvider);

  /// Smaže neplatné kartičky vzniklé z halucinací AI.
  Future<int> cleanupInvalidCards() {
    return _ref.read(flashcardRepositoryProvider).cleanupInvalidFlashcards();
  }

  /// Přeloží stará anglická zadání kartiček do češtiny.
  Future<int> migrateLegacyCards(GeminiBatchClient gemini) {
    return _ref.read(flashcardGenerationServiceProvider).autoMigrateLegacyCardsToCzech(gemini);
  }

  /// Vytvoří kartičky z dosud nezpracovaných chyb ze všech lekcí.
  Future<Result<int>> generateFromErrors() {
    return _ref.read(flashcardGenerationServiceProvider).generateFlashcardsFromErrors(
          limit: 15,
          geminiClient: gemini,
        );
  }

  /// Uloží hodnocení kartičky (0 = Znovu … 3 = Snadné) a přeplánuje ji.
  Future<void> review(Flashcard card, int rating) {
    return _ref.read(flashcardRepositoryProvider).reviewFlashcard(flashcardId: card.id, rating: rating);
  }

  /// Trvale smaže kartičku.
  Future<void> delete(Flashcard card) {
    return _ref.read(flashcardRepositoryProvider).deleteFlashcard(card.id);
  }

  /// Přehraje rodilou výslovnost [text]u; vrátí false, pokud se nepodařilo.
  Future<bool> speak(String text) => _ref.read(geminiTtsServiceProvider).speak(text);

  /// Vyhodnotí mluvenou odpověď studenta na kartičku [card] se zadáním [prompt].
  Future<PronunciationAnalysis?> evaluateAnswer({
    required List<int> audio,
    required Flashcard card,
    required String prompt,
  }) {
    return _ref.read(pronunciationServiceProvider).evaluateSpokenAnswer(
          audioBytes: audio,
          expectedEnglish: card.backText,
          promptContext: prompt,
        );
  }

  /// Nový nahrávač mluvené odpovědi.
  AnswerRecorder createRecorder() => AnswerRecorder(_ref.read(audioCaptureServiceProvider));

  /// Nový resolver českých zadání na líci kartiček.
  CardFrontResolver createFrontResolver({required void Function() onTranslated}) {
    return CardFrontResolver(
      saveFront: (id, text) =>
          _ref.read(flashcardRepositoryProvider).updateFlashcardFrontText(id, text),
      geminiClient: () => gemini,
      onTranslated: onTranslated,
    );
  }
}

/// Poskytuje [FlashcardsController].
final flashcardsControllerProvider =
    Provider<FlashcardsController>(FlashcardsController.new);
