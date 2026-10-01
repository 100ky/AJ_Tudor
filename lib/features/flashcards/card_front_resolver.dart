import '../../core/utils/logger.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../../services/flashcards/flashcard_generation_service.dart';
import '../../services/gemini/gemini_batch_client.dart';

/// Zajistí, aby líc kartičky vždy ukazoval české zadání.
///
/// Staré kartičky mohou mít na líci anglickou šablonu. Resolver pak zkusí
/// vytáhnout český překlad z vysvětlení, nebo ho na pozadí nechá přeložit
/// a výsledek uloží do databáze, aby byl trvalý.
class CardFrontResolver {
  /// Text zobrazený, dokud na pozadí běží překlad zadání.
  static const String translatingPlaceholder = 'Překládám zadání do češtiny...';

  /// Uloží nové zadání kartičky do databáze.
  final void Function(int cardId, String frontText) saveFront;

  /// Vrátí aktuálního Gemini klienta (nebo null bez API klíče).
  final GeminiBatchClient? Function() geminiClient;

  /// Volá se, když doběhne překlad a líc je potřeba překreslit.
  final void Function() onTranslated;

  final Map<int, String> _resolved = {};
  final Set<int> _translating = {};

  CardFrontResolver({
    required this.saveFront,
    required this.geminiClient,
    required this.onTranslated,
  });

  /// České zadání pro líc [card], případně [translatingPlaceholder].
  String resolve(Flashcard card) {
    // 1. Pokud již máme přeloženo v lokální paměti
    final cached = _resolved[card.id];
    if (cached != null) return cached;

    final raw = card.frontText.trim();

    // 2. Pokud je text již v čisté češtině (žádné legacy šablony ani anglické uvozovky)
    if (!FlashcardRepository.isLegacyOrEnglishFront(
      raw,
      backText: card.backText,
      sourceSentence: card.sourceSentence,
    )) {
      return raw;
    }

    // 3. Pokus o okamžitou extrakci českého překladu z vysvětlení (např. "(jeden měsíc)")
    final extracted = FlashcardRepository.extractCzechFromExplanation(card.explanation);
    if (extracted != null && extracted.isNotEmpty) {
      _resolved[card.id] = extracted;
      // Na pozadí rovnou uložíme do SQLite, ať je to trvalé
      saveFront(card.id, extracted);
      return extracted;
    }

    // 4. Pokud je kartička legacy/anglická, spustíme okamžitý on-demand překlad
    final gemini = geminiClient();
    if (gemini != null) {
      _translate(card, gemini);
      // 5. Dokud překlad běží, nezobrazujeme angličtinu ani chybnou šablonu
      return translatingPlaceholder;
    }

    // 6. Gemini není k dispozici — zobrazíme surový text (lepší než nekonečný spinner)
    return raw;
  }

  void _translate(Flashcard card, GeminiBatchClient gemini) {
    if (!_translating.add(card.id)) return;

    FlashcardGenerationService.translateToCzech(gemini, card.backText).then((clean) {
      if (clean != null) {
        _resolved[card.id] = clean;
        saveFront(card.id, clean);
        onTranslated();
      }
    }).catchError((err) {
      L.w('On-demand překlad kartičky #${card.id} selhal: $err');
    }).whenComplete(() {
      _translating.remove(card.id);
    });
  }
}
