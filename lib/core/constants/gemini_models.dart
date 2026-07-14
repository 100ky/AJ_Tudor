class GeminiModels {
  // Aktuální modely (červenec 2026)
  static const String flash3_5 = 'gemini-3.5-flash';
  static const String flashLite3_1 = 'gemini-3.1-flash-lite';
  static const String flash2_5 = 'gemini-2.5-flash';

  // --- Model pro Multimodal Live API (WebSocket / Voice Tutor) ---
  // Používáme specifický "native audio" model, který podporuje BidiGenerateContent
  static const String liveVoiceModel = 'gemini-2.5-flash-native-audio-preview-12-2025';
  static const String defaultLiveModel = liveVoiceModel;

  static const String embedding = 'text-embedding-004';

  // Výchozí model pro chat
  static const String defaultModel = flash3_5;

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
      case liveVoiceModel:
        return 'Gemini 2.5 Native Audio (Hlasový)';
      default:
        return model;
    }
  }
}
