import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:aj_tudor/services/prompt/live_tutor_prompts.dart';

void main() {
  const greeting =
      'Hello! Please greet me and start the conversation according to your instructions.';

  group('LiveTutorPrompts.opening', () {
    test('free talk starts with a casual greeting', () {
      final prompt = LiveTutorPrompts.opening(scenarioContext: '__free_talk__', briefing: 'x');
      expect(prompt, startsWith(greeting));
      expect(prompt, contains('casual and warm greeting as a friend'));
    });

    test('a role-play scenario is introduced immediately', () {
      final prompt = LiveTutorPrompts.opening(
        scenarioContext: 'Act as a waiter',
        preparedOpener: 'ignored',
      );
      expect(prompt, '$greeting Introduce the role-play scenario and immediately start playing your role.');
    });

    test('a prepared topic opener wins over the last lesson briefing', () {
      final prompt = LiveTutorPrompts.opening(
        preparedOpener: 'Have you tried night trains?',
        briefing: 'Past simple',
      );
      expect(prompt, contains('prepared hook/question: "Have you tried night trains?"'));
      expect(prompt, isNot(contains('last lesson')));
    });

    test('without a prepared topic the tutor follows up on the last lesson', () {
      final prompt = LiveTutorPrompts.opening(preparedOpener: '', briefing: 'Past simple');
      expect(prompt, contains('Refer briefly to our last lesson'));
    });

    test('with nothing prepared the tutor greets casually', () {
      expect(LiveTutorPrompts.opening(), contains('casual and warm greeting as a friend'));
    });
  });

  test('mid-session instructions are clearly marked', () {
    expect(LiveTutorPrompts.systemInstruction('Slow down.'),
        '[SYSTEM INSTRUCTION - NOT FROM STUDENT] Slow down.');
    expect(LiveTutorPrompts.directorWhisper('Ask about the trip.'),
        '[DIRECTOR WHISPER] Ask about the trip.');
  });

  test('a lesson opens with the first expression and keeps the tutor up to date', () {
    expect(LiveTutorPrompts.opening(lesson: true, briefing: 'Last time: boats.'), LiveTutorPrompts.lessonOpening);
    expect(LiveTutorPrompts.lessonOpening, contains('REŽIM LEKCE'));
    expect(
      LiveTutorPrompts.lessonProgress(done: ['take a sick day'], remaining: ['once a week', 'work on']),
      'Lekce: student už zvládl "take a sick day". Zbývá: "once a week", "work on".',
    );
    expect(LiveTutorPrompts.lessonProgress(done: ['work on'], remaining: []), contains('lekci uzavři'));
    expect(LiveTutorPrompts.lessonTimeUp, contains('čas vypršel'));
  });

  test('a whisper with a flashcard tells the tutor to let the student say the phrase', () {
    final whisper = LiveTutorPrompts.directorWhisper(
      'Ask what he does when he feels ill.',
      cardTarget: 'take a sick day',
    );
    expect(whisper, startsWith('[DIRECTOR WHISPER] Ask what he does when he feels ill.'));
    expect(whisper, contains('"take a sick day"'));
    expect(whisper, contains('do not say it first'));
  });

  test('directorWhisper masks the literal English phrase if leaked inside whisper', () {
    final whisper = LiveTutorPrompts.directorWhisper(
      'Ask him to say where it is warm.',
      cardTarget: 'where it is warm',
      cardCzech: 'kde je teplo',
    );
    expect(whisper, startsWith('[DIRECTOR WHISPER] Ask him to say [expression for "kde je teplo" - DO NOT SAY IT].'));
    expect(whisper, isNot(contains('Ask him to say where it is warm')));
  });

  test('changeTopicWithCards avoids profile topics and nudges sampled flashcards safely', () {
    expect(LiveTutorPrompts.changeTopicWithCards(const []), LiveTutorPrompts.changeTopicNow);

    final prompt = LiveTutorPrompts.changeTopicWithCards([
      ConversationCard(id: 1, czech: 'stěhovat se', english: 'move out'),
      ConversationCard(id: 2, czech: 'záloha', english: 'deposit'),
    ]);
    expect(prompt, contains(LiveTutorPrompts.changeTopicNow));
    expect(prompt, contains('"stěhovat se"'));
    expect(prompt, contains('"záloha"'));
    expect(prompt, contains('Do NOT say the English expressions ("move out", "deposit") yourself'));
  });
}
