/// Třída obsahující identifikátory a konfiguraci modelů Google Gemini.
/// 
/// Centralizuje názvy modelů pro různé účely (chat, audio, embedding) a poskytuje
/// lidsky čitelné popisky pro uživatelské rozhraní.
class GeminiModels {
  // Aktuální verze modelů Gemini (k červenci 2026)
  static const String flash3_5 = 'gemini-3.5-flash';
  static const String flashLite3_1 = 'gemini-3.1-flash-lite';
  static const String flash2_5 = 'gemini-2.5-flash';

  // --- Model pro Multimodal Live API (WebSocket / Voice Tutor) ---
  /// Model optimalizovaný pro zpracování audia v reálném čase s nízkou latencí.
  /// Podporuje přímý audio vstup i výstup (Native Audio).
  static const String liveVoiceModel = 'gemini-2.5-flash-native-audio-preview-12-2025';
  
  /// Výchozí model používaný pro hlasového tutora.
  static const String defaultLiveModel = liveVoiceModel;

  /// Model pro generování textových embeddingů (vyhledávání a sémantická analýza).
  static const String embedding = 'text-embedding-004';

  /// Výchozí model pro standardní textový chat.
  static const String defaultModel = flash3_5;

  /// Seznam modelů, které si uživatel může vybrat v nastavení pro textový chat.
  static const List<String> allowedChatModels = [
    flash3_5,
    flashLite3_1,
    flash2_5,
  ];

  /// Vrátí přehledný český název modelu pro zobrazení v UI.
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
