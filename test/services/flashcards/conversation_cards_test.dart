import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:flutter_test/flutter_test.dart';

ConversationCard _card(int id, String english, [String czech = 'cz']) =>
    ConversationCard(id: id, czech: czech, english: english);

void main() {
  group('target patterns', () {
    bool said(String back, String text) => _card(1, back).matches(ConversationCards.normalize(text));

    test('a phrase matches as whole words in any case and with punctuation', () {
      expect(said('take a sick day', 'Tomorrow I will TAKE a sick day, I think.'), isTrue);
      expect(said('take a sick day', 'I will take a sick-day.'), isTrue);
      expect(said('take a sick day', 'I will take a day off.'), isFalse);
      expect(said('in front of people', 'I am shy in front of people.'), isTrue);
      expect(said('harvest', 'We harvested herbs.'), isFalse);
    });

    test('contractions and their long forms are the same', () {
      expect(said("don't speak", 'In my head I do not speak English well.'), isTrue);
      expect(said('did not relax', "This weekend I didn't relax."), isTrue);
      expect(said("I'm cooking", 'Today I am cooking soup.'), isTrue);
      expect(said("can't run", 'I cannot run today.'), isTrue);
    });

    test('notes in brackets, variants, a leading "to" and placeholders', () {
      expect(said('have been working (for some time)', 'I have been working on it.'), isTrue);
      expect(said('unwind / chill out', 'I need to chill out.'), isTrue);
      expect(said('to recommend', 'Can you recommend a film?'), isTrue);
      expect(said("clear one's head", 'Running clears my head.'), isFalse);
      expect(said("clear one's head", 'I go running to clear my head.'), isTrue);
      expect(said('be created for', 'The app was created for supervisors.'), isTrue);
    });

    test('whole sentences and short common words cannot be checked in a conversation', () {
      expect(ConversationCards.targetPatterns('To start things off what is your very first sentence'), isEmpty);
      for (final word in ['Go', 'has', 'been', 'least', 'fun', 'watch']) {
        expect(ConversationCards.targetPatterns(word), isEmpty, reason: word);
      }
      expect(ConversationCards.targetPatterns('winterized'), hasLength(1));
      expect(ConversationCards.targetPatterns('at least'), hasLength(1));
      expect(ConversationCards.targetPatterns('sth'), isEmpty);
    });
  });

  group('completing cards', () {
    test('a card is completed once, and only when the tutor did not say the phrase', () {
      final cards = ConversationCards([_card(1, 'take a sick day'), _card(2, 'winterized')]);

      expect(
        cards.completeBy('I will take a sick day.', recentTutorLines: ['Zkus to říct: I will take a sick day.']),
        isEmpty,
      );
      expect(cards.completeBy('Yesterday I winterized the boat.').map((c) => c.id), [2]);
      expect(cards.completeBy('I winterized it again.'), isEmpty);
      expect(cards.completed.map((c) => c.id), [2]);
    });

    test('cards that cannot be checked are left out', () {
      final cards = ConversationCards([_card(1, 'Go'), _card(2, 'take place')]);
      expect(cards.cards.map((c) => c.id), [2]);
      expect(cards.completeBy("Let's go!"), isEmpty);
    });
  });

  group('pool for the director', () {
    test('oldest first, at most fifteen, without completed and woven cards', () {
      var now = DateTime(2026, 11, 7, 10);
      final cards = ConversationCards(
        [for (var i = 1; i <= 20; i++) _card(i, 'phrase number $i')],
        clock: () => now,
      );
      expect(cards.directorPool().map((c) => c.id), [for (var i = 1; i <= 15; i++) i]);

      cards.completeBy('I said phrase number 1 myself.');
      cards.markWoven(cards.byId(2)!);
      // Další kartička nejdřív za dvě minuty, ať hovor nesklouzne do zkoušení
      expect(cards.directorPool(), isEmpty);

      now = now.add(ConversationCards.cardSpacing);
      final pool = cards.directorPool().map((c) => c.id).toList();
      expect(pool.first, 3);
      expect(pool, hasLength(15));
      expect(pool, isNot(contains(1)));
      expect(pool, isNot(contains(2)));
    });
  });
}
