import '../flashcards/conversation_cards.dart';

/// Pokyny posílané hlasovému tutorovi během živého hovoru (Gemini Live).
abstract final class LiveTutorPrompts {
  static const String _casualGreeting =
      " Start with a casual and warm greeting as a friend (do NOT introduce yourself, say your name or where you are from). Share a small, natural detail about your day or mood (following your system instructions example) and ask an open question on a fresh, everyday or unexpected topic to kick off the chat (do NOT ask about the student's work, IT projects, grilling, garden, sailing, or TV series from their profile).";

  /// Skrytá úvodní zpráva, kterou tutor po připojení zahájí konverzaci.
  ///
  /// Podle režimu: volný hovor, role-play scénář, připravené téma
  /// ([preparedOpener]), navázání na minulou lekci ([briefing]), nebo pozdrav.
  static String opening({
    String? scenarioContext,
    String? preparedOpener,
    String? briefing,
    bool lesson = false,
  }) {
    if (lesson) return lessonOpening;
    var prompt = "Hello! Please greet me and start the conversation according to your instructions.";
    if (scenarioContext == '__free_talk__') {
      prompt += _casualGreeting;
    } else if (scenarioContext != null) {
      prompt += " Introduce the role-play scenario and immediately start playing your role.";
    } else if (preparedOpener != null && preparedOpener.isNotEmpty) {
      prompt += ' Open the conversation naturally and casually as AJ Tudor using this prepared hook/question: "$preparedOpener". Do NOT introduce yourself or ask generic questions about pets/hobbies.';
    } else if (briefing != null && briefing.isNotEmpty) {
      prompt += " Refer briefly to our last lesson and follow up on the recommended topic or question.";
    } else {
      prompt += _casualGreeting;
    }
    return prompt;
  }

  /// Úvod hovoru v režimu Lekce (pozdrav a rovnou první výraz).
  static const String lessonOpening =
      "Hello! Please greet me in one short sentence and start today's flashcard lesson according to your "
      "REŽIM LEKCE instructions: say how many expressions we will practise and start with the first card.";

  /// Průběh lekce pro tutora: které kartičky student už zvládl a které zbývají.
  static String lessonProgress({required List<String> done, required List<String> remaining}) {
    final said = done.map((e) => '"$e"').join(', ');
    if (remaining.isEmpty) {
      return 'Lekce: student už zvládl všechny kartičky ($said). Až dokončíš aktuální krok, lekci uzavři.';
    }
    return 'Lekce: student už zvládl ${said.isEmpty ? 'zatím žádnou kartičku' : said}. '
        'Zbývá: ${remaining.map((e) => '"$e"').join(', ')}.';
  }

  /// Vypršel čas lekce.
  static const String lessonTimeUp =
      'Lekce: čas vypršel. Dokonči aktuální výraz a lekci uzavři, další výrazy už nezačínej.';

  /// Skrytá instrukce uprostřed hovoru – Live API po úvodním setupu nepodporuje
  /// roli `system`, proto ji posíláme jako `user` s tímto prefixem.
  static String systemInstruction(String instruction) =>
      '[SYSTEM INSTRUCTION - NOT FROM STUDENT] $instruction';

  /// Rada režiséra hovoru (VoiceDirectorAgent) pro tutora.
  ///
  /// [cardTarget] je výraz z kartičky, ke kterému rada vede: student ho má říct sám,
  /// zopakování po tutorovi kartičku nesplní. Pokud režisér výraz omylem napsal
  /// přímo do rady [whisper], zamaskuje se, aby ho tutor nevyslovil první.
  ///
  /// Rada vzniká z hovoru před poslední replikou studenta. Když student mezitím začal
  /// o něčem jiném, tutor má zůstat u studenta (lekce 36: student začal o prodeji
  /// monitoru a rada z dřívějška vrátila hovor k výletům).
  static String directorWhisper(String whisper, {String? cardTarget, String? cardCzech}) {
    if (cardTarget == null || cardTarget.isEmpty) return '[DIRECTOR WHISPER] $whisper$_followStudent';
    final maskedWhisper = whisper.replaceAll(
      RegExp(RegExp.escape(cardTarget), caseSensitive: false),
      '[expression for "${cardCzech ?? cardTarget}" - DO NOT SAY IT]',
    );
    return '[DIRECTOR WHISPER] $maskedWhisper$_followStudent (Flashcard practice: the student is learning to say "$cardTarget". '
        'Let them say it themselves, so do not say it first. If they say it in Czech or ask how to say it, help them as usual.)';
  }

  static const String _followStudent =
      ' (Use this only if it still fits what the student is talking about now. '
      'If they have moved on to something else, stay with what they brought up.)';

  /// Student odpovídá opakovaně jen pár slovy – zmírnit a odlehčit.
  ///
  /// Téma se kvůli tomu hned nemění: krátké odpovědi bývají i z jiných důvodů
  /// (lekce 36: student smrkal) a tutor pak skočil na nové téma uprostřed živého.
  static const String frustrationRecalibration =
      'STUDENT IS GIVING VERY SHORT ANSWERS. They might be tired or unsure. Validate their effort and be encouraging. '
      'Ask an easier question about the same topic (yes/no or this-or-that). '
      'Move to a new, light topic only if they clearly do not want to talk about this one.';

  /// Tutor několikrát za sebou žádal studenta, ať zopakuje, co řekl.
  ///
  /// Lekce 36: student smrkal a pak česky vysvětloval „Jsem akorát smrkal“, tutor
  /// třikrát chtěl „repeat your answer in English“ a změna tématu to jen zakryla.
  static const String breakRepairLoop =
      'You have asked the student several times to repeat what they said. Do NOT ask them to repeat again. '
      'Respond to what they actually said, even if it was in Czech or about something else '
      '(they may have coughed, sneezed or been interrupted). '
      'If you still do not know what they meant, re-ask YOUR last question in simpler words and continue the same topic.';

  /// Student klepl na „Změnit téma“ – tutor má hned plynule přejít k novému tématu mimo profil.
  static const String changeTopicNow =
      "CRITICAL INSTRUCTION: The student just tapped 'Next Topic' / 'Change Topic'. "
      "Immediately abandon the previous discussion. "
      "Naturally acknowledge changing the subject in English in one brief, friendly sentence "
      "(for example: \"Sure, let's switch gears!\" or \"Alright, let's move on to something else!\"), "
      "smoothly introduce a completely fresh, unexpected, and engaging topic OUTSIDE the student's profile facts "
      "(strictly AVOID their work, IT/Power Platform, food/grilling, gardening, sailing/boat, and TV series/Marvel/anime), "
      "such as an intriguing 'what if' dilemma, travel & hotels, future technology, cultural curiosity, or an everyday life situation, "
      "and ask ONE clear open-ended question to invite the student to speak.";

  /// Změna tématu s nenápadným zapojením 1–2 dnešních kartiček mimo profil studenta.
  static String changeTopicWithCards(List<ConversationCard> sampleCards) {
    if (sampleCards.isEmpty) return changeTopicNow;
    final hints = sampleCards.map((c) => '"${c.czech}" (target: "${c.english}")').join(', ');
    final forbiddenEn = sampleCards.map((c) => '"${c.english}"').join(', ');
    return '$changeTopicNow '
        'If possible, steer the new random topic so the student has a natural opportunity to express one of these concepts: $hints. '
        'CRITICAL: Do NOT say the English expressions ($forbiddenEn) yourself in your question—let the student use them!';
  }

  /// Po obnovení spojení zůstala poslední replika studenta bez odpovědi – tutor na ni odpoví hned.
  static const String answerAfterReconnect =
      "The connection dropped before you answered the student's last message in Recent Exchanges. "
      "Answer it right now, naturally and briefly, as AJ Tudor. "
      "If the student was asking whether you are still there, reassure them in a few words and carry on. "
      "Do NOT talk about technical problems.";

  /// Spojení navázalo na stejný hovor (souvislý hovor) a poslední replika studenta zůstala
  /// bez odpovědi. Model hovor zná, repliku [studentReply] ale pro jistotu dostane znovu:
  /// spojení mohlo spadnout dřív, než ji server celou přijal.
  static String answerAfterResume(String studentReply) =>
      "The connection dropped before you answered the student. "
      "Their last message was: \"$studentReply\". "
      "Answer it right now, naturally and briefly, as AJ Tudor. "
      "If the student was asking whether you are still there, reassure them in a few words and carry on. "
      "Do NOT talk about technical problems.";

  /// Konverzace se zacyklila – v příštím tahu nenápadně změnit téma.
  static const String changeTopicSilently =
      "CRITICAL INSTRUCTION: Okamžitě opusti současné téma hovoru, "
      "protože se konverzace zacyklila. Přestaň klást otázky k dosavadnímu okruhu "
      "a plynule přejdi na zcela nové, neotřelé téma mimo ohraná fakta z profilu studenta "
      "(vyhni se práci v IT, grilování, zahradě, lodi i seriálům). Použij přirozený "
      "oslí můstek. Neupozorňuj nahlas, že měníš téma na příkaz systému.";
}
