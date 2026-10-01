/// Pokyny posílané hlasovému tutorovi během živého hovoru (Gemini Live).
abstract final class LiveTutorPrompts {
  static const String _casualGreeting =
      " Start with a casual and warm greeting as a friend (do NOT introduce yourself, say your name or where you are from). Share a small, natural detail about your day or mood (following your system instructions example) and ask an open question to kick off the chat.";

  /// Skrytá úvodní zpráva, kterou tutor po připojení zahájí konverzaci.
  ///
  /// Podle režimu: volný hovor, role-play scénář, připravené téma
  /// ([preparedOpener]), navázání na minulou lekci ([briefing]), nebo pozdrav.
  static String opening({
    String? scenarioContext,
    String? preparedOpener,
    String? briefing,
  }) {
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

  /// Skrytá instrukce uprostřed hovoru – Live API po úvodním setupu nepodporuje
  /// roli `system`, proto ji posíláme jako `user` s tímto prefixem.
  static String systemInstruction(String instruction) =>
      '[SYSTEM INSTRUCTION - NOT FROM STUDENT] $instruction';

  /// Rada režiséra hovoru (VoiceDirectorAgent) pro tutora.
  static String directorWhisper(String whisper) => '[DIRECTOR WHISPER] $whisper';

  /// Student odpovídá opakovaně jen pár slovy – zmírnit a odlehčit.
  static const String frustrationRecalibration =
      'STUDENT IS GIVING VERY SHORT ANSWERS. They might be frustrated or tired. STOP asking difficult questions. Validate their effort, be extremely encouraging, and switch to a very easy, fun, and relaxing topic immediately.';

  /// Student klepl na „Změnit téma“ – tutor má hned plynule přejít k novému tématu.
  static const String changeTopicNow =
      "CRITICAL INSTRUCTION: The student just tapped 'Next Topic' / 'Change Topic'. "
      "Immediately abandon the previous discussion. "
      "Naturally acknowledge changing the subject in English in one brief, friendly sentence "
      "(for example: \"Sure, let's switch gears!\" or \"Alright, let's move on to something else!\"), "
      "smoothly introduce a completely fresh and engaging topic suited to the student's level and interests, "
      "and ask ONE clear open-ended question to invite the student to speak.";

  /// Konverzace se zacyklila – v příštím tahu nenápadně změnit téma.
  static const String changeTopicSilently =
      "CRITICAL INSTRUCTION: Okamžitě opusti současné téma hovoru, "
      "protože se konverzace zacyklila. Přestaň klást otázky k dosavadnímu okruhu "
      "a plynule přejdi na absolutně novou oblast zájmů studenta. Použij přirozený "
      "oslí můstek. Neupozorňuj nahlas, že měníš téma na příkaz systému.";
}
