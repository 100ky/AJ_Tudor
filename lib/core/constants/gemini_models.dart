/// Třída obsahující identifikátory a konfiguraci modelů Google Gemini.
/// 
/// Centralizuje názvy modelů pro různé účely (chat, audio, embedding) a poskytuje
/// lidsky čitelné popisky pro uživatelské rozhraní.
class GeminiModels {
  // Aktuální verze modelů Gemini (k září 2026)
  static const String flash3_8 = 'gemini-3.8-flash';   // vydán 2. 9. 2026
  static const String flash3_7 = 'gemini-3.7-flash';   // vydán 13. 8. 2026
  static const String flash3_6 = 'gemini-3.6-flash';
  static const String flash3_5 = 'gemini-3.5-flash';
  static const String flashLite3_5 = 'gemini-3.5-flash-lite';
  static const String flashLite3_1 = 'gemini-3.1-flash-lite';
  static const String pro3_1 = 'gemini-3.1-pro-preview';

  // --- Modely pro Speech-to-Text a Text-to-Speech ---
  /// Model pro přesný přepis audia (Speech-to-Text) s časovými značkami slov a detekcí jazyka.
  static const String transcribe = 'gemini-3.5-transcribe';

  /// Model pro živý přepis audia přes WebSockets v reálném čase.
  static const String transcribeLive = 'gemini-3.5-transcribe-live';

  /// Model pro syntézu přirozené řeči (Text-to-Speech) s audio tagy pro tempo a intonaci.
  static const String tts = 'gemini-3.1-flash-tts-preview';

  // --- Model pro Multimodal Live API (WebSocket / Voice Tutor) ---
  /// Model optimalizovaný pro real-time dialog a voice-first AI aplikace.
  /// Nativní A2A (audio-to-audio) s nízkou latencí a vyšší kvalitou porozumění.
  static const String liveVoiceModel = 'gemini-3.1-flash-live-preview';
  
  /// Výchozí model používaný pro hlasového tutora.
  static const String defaultLiveModel = liveVoiceModel;

  /// Model pro generování multimodálních embeddingů (text, obraz, audio, video).
  /// Endpoint dle dokumentace: gemini-embedding-2-preview
  static const String embedding = 'gemini-embedding-2-preview';

  /// Výchozí model pro standardní textový chat.
  /// gemini-3.8-flash: vydán 2. 9. 2026, nejinteligentnější Flash model optimalizovaný pro
  /// software engineering a agentní workflows.
  static const String defaultModel = flash3_8;

  /// Seznam modelů, které si uživatel může vybrat v nastavení pro textový chat.
  static const List<String> allowedChatModels = [
    flash3_8,
    flash3_7,
    flash3_6,
    flash3_5,
    flashLite3_5,
    flashLite3_1,
    pro3_1,
  ];

  /// Vrátí přehledný český název modelu pro zobrazení v UI.
  static String getLabel(String model) {
    switch (model) {
      case flash3_8:
        return 'Gemini 3.8 Flash (Nejnovější ✨)';
      case flash3_7:
        return 'Gemini 3.7 Flash (Výkonný)';
      case flash3_6:
        return 'Gemini 3.6 Flash (Stabilní)';
      case flash3_5:
        return 'Gemini 3.5 Flash (Rychlý)';
      case flashLite3_5:
        return 'Gemini 3.5 Flash-Lite (Úsporný)';
      case flashLite3_1:
        return 'Gemini 3.1 Flash-Lite (Záložní)';
      case pro3_1:
        return 'Gemini 3.1 Pro (Expertní úvahy 🧠)';
      case liveVoiceModel:
        return 'Gemini 3.1 Flash Live (Hlasový)';
      case transcribe:
        return 'Gemini 3.5 Transcribe (Přepis)';
      case tts:
        return 'Gemini 3.1 Flash TTS (Výslovnost)';
      default:
        return model;
    }
  }
}
