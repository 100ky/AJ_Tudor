import '../../core/utils/logger.dart';
import '../../data/database/app_database.dart';
import '../../services/flashcards/flashcard_generation_service.dart';
import '../../services/gemini/gemini_batch_client.dart';

/// Zajisti, aby rub karticky mel skutecne vysvetleni vyrazu.
///
/// Karticky ulozene z prekladu slova mely misto vysvetleni jen vetu, ze ktere slovo
/// pochazi ("Z věty tutora: ..."), a ta se na rubu zobrazila dvakrat. U takove karticky
/// resolver na pozadi necha vysvetleni vytvorit a ulozi ho do databaze.
class CardExplanationResolver {
  /// Text na rubu, dokud se vysvetleni pripravuje.
  static const String loadingText = 'Připravuji vysvětlení…';

  /// Ulozi vysvetleni karticky do databaze.
  final void Function(int cardId, String explanation) saveExplanation;

  /// Vrati aktualniho Gemini klienta (nebo null bez API klice).
  final GeminiBatchClient? Function() geminiClient;

  /// Vola se, kdyz vysvetleni dobehne a rub je potreba prekreslit.
  final void Function() onExplained;

  final Map<int, String> _resolved = {};
  final Set<int> _loading = {};
  // Karticky, u kterych model vysvetleni nevratil: rub pak box nezobrazi a znovu se nezkousi
  final Set<int> _failed = {};

  CardExplanationResolver({
    required this.saveExplanation,
    required this.geminiClient,
    required this.onExplained,
  });

  /// Karticka nema skutecne vysvetleni, jen zastupny text nebo puvodni vetu.
  static bool isPlaceholder(String explanation) {
    final text = explanation.trim();
    return text.isEmpty ||
        text.startsWith('Z věty tutora:') ||
        text == 'Slovíčko z konverzace s tutorem' ||
        text == 'Oprava z konverzace' ||
        text == 'Oprava chyby z konverzace';
  }

  /// Vysvetleni pro rub [card], behem pripravy [loadingText], nebo null, kdyz neni co ukazat.
  ///
  /// Zavolat se da uz pri zobrazeni lice, at je vysvetleni hotove, nez se karticka otoci.
  String? resolve(Flashcard card) {
    final cached = _resolved[card.id];
    if (cached != null) return cached;
    if (!isPlaceholder(card.explanation)) return card.explanation.trim();
    if (_failed.contains(card.id)) return null;

    final gemini = geminiClient();
    if (gemini == null) return null;
    _explain(card, gemini);
    return loadingText;
  }

  void _explain(Flashcard card, GeminiBatchClient gemini) {
    if (!_loading.add(card.id)) return;

    FlashcardGenerationService.explainExpression(
      gemini,
      english: card.backText,
      czech: card.frontText,
      sentence: card.sourceSentence,
    ).then((explanation) {
      if (explanation != null) {
        _resolved[card.id] = explanation;
        saveExplanation(card.id, explanation);
      } else {
        _failed.add(card.id);
      }
    }).catchError((err) {
      _failed.add(card.id);
      L.w('Vysvětlení kartičky #${card.id} se nepodařilo připravit: $err');
    }).whenComplete(() {
      _loading.remove(card.id);
      onExplained();
    });
  }
}
