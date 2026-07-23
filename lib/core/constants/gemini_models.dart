/// Třída obsahující identifikátory a konfiguraci modelů Google Gemini.
/// 
/// Centralizuje názvy modelů pro různé účely (chat, audio, embedding) a poskytuje
/// lidsky čitelné popisky pro uživatelské rozhraní.
class GeminiModels {
  // Aktuální verze modelů Gemini (k červenci 2026)
  static const String flash3_6 = 'gemini-3.6-flash';
  static const String flash3_5 = 'gemini-3.5-flash';
  static const String flashLite3_5 = 'gemini-3.5-flash-lite';
  static const String flashLite3_1 = 'gemini-3.1-flash-lite';
  static const String flash2_5 = 'gemini-2.5-flash';

  // --- Model pro Multimodal Live API (WebSocket / Voice Tutor) ---
  /// Model optimalizovaný pro real-time dialog a voice-first AI aplikace.
  /// Nativní A2A (audio-to-audio) s nízkou latencí a vyšší kvalitou porozumění.
  static const String liveVoiceModel = 'gemini-3.1-flash-live-preview';
  
  /// Výchozí model používaný pro hlasového tutora.
  static const String defaultLiveModel = liveVoiceModel;

  /// Model pro generování multimodálních embeddingů (text, obraz, audio, video).
  static const String embedding = 'gemini-embedding-2';

  /// Výchozí model pro standardní textový chat.
  static const String defaultModel = flash3_6;

  /// Seznam modelů, které si uživatel může vybrat v nastavení pro textový chat.
  static const List<String> allowedChatModels = [
    flash3_6,
    flash3_5,
    flashLite3_5,
    flashLite3_1,
  ];

  /// Vrátí přehledný český název modelu pro zobrazení v UI.
  static String getLabel(String model) {
    switch (model) {
      case flash3_6:
        return 'Gemini 3.6 Flash (Doporučený)';
      case flash3_5:
        return 'Gemini 3.5 Flash (Výkonný)';
      case flashLite3_5:
        return 'Gemini 3.5 Flash-Lite (Úsporný)';
      case flashLite3_1:
        return 'Gemini 3.1 Flash-Lite (Záložní)';
      case liveVoiceModel:
        return 'Gemini 3.1 Flash Live (Hlasový)';
      default:
        return model;
    }
  }
}
