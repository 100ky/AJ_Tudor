import '../../data/database/app_database.dart';
import 'conversation_cards.dart';

/// Kartičky na dnešní opakování, které může splnit hovor. Výslovnost hovor neověří,
/// ta se zkouší v kartičkách. [due] mají být seřazené od nejdéle čekající.
ConversationCards conversationCardsFromDue(Iterable<Flashcard> due) => ConversationCards([
      for (final card in due)
        if (card.errorType != 'pronunciation')
          ConversationCard(id: card.id, czech: card.frontText.trim(), english: card.backText.trim()),
    ]);
