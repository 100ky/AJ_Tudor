class GeminiModels {
  // Aktuální modely (červenec 2026)
  // Gemini 3.5 Flash – nejnovější, nejrychlejší, doporučený
  static const String flash3_5 = 'gemini-3.5-flash';

  // Gemini 3.1 Flash-Lite – levnější, pro batch analýzu a vysoký objem
  static const String flashLite3_1 = 'gemini-3.1-flash-lite';

  // --- Modely pro Multimodal Live API (WebSocket / Voice Tutor) ---
  // Použijeme model, který server aktivně podporuje pro BidiGenerateContent v tomto tieru
  static const String liveVoiceModel = 'gemini-2.5-flash-native-audio-latest';

  // Gemini 2.5 Flash – starší ale stále funkční (retirement: říjen 2026)
  static const String flash2_5 = 'gemini-2.5-flash';

  // Specializované modely
  static const String embedding = 'text-embedding-004';

  // Výchozí model pro chat
  static const String defaultModel = flash3_5;
  static const String defaultLiveModel = liveVoiceModel;

  // Seznam povolených modelů pro textový chat v nastavení
  static const List<String> allowedChatModels = [
    flash3_5,
    flashLite3_1,
    flash2_5,
  ];

  static String getLabel(String model) {
    switch (model) {
      case flash3_5:
        return 'Gemini 3.5 Flash (Doporučený)';
      case flashLite3_1:
        return 'Gemini 3.1 Flash-Lite (Úsporný)';
      case flash2_5:
        return 'Gemini 2.5 Flash (Záložní)';
      default:
        return model;
    }
  }
}
