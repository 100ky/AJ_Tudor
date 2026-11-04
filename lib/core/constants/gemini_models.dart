/// Třída obsahující identifikátory a konfiguraci modelů Google Gemini.
/// 
/// Centralizuje názvy modelů pro různé účely (chat, audio, embedding) a poskytuje
/// lidsky čitelné popisky pro uživatelské rozhraní.
class GeminiModels {
  // Aktuální verze modelů Gemini (k listopadu 2026, aistudio.google.com/docs/deprecations).
  // gemini-3.7-flash a gemini-3.5-flash jsou zastaralé (API je přesměruje na 3.8 a 3.6 Flash),
  // gemini-2.5-flash se vypíná 1. 12. 2026.
  static const String argon4 = 'gemini-4-argon';       // Gemini 4 Argon
  static const String flash3_8 = 'gemini-3.8-flash';   // vydán 2. 9. 2026
  static const String flash3_6 = 'gemini-3.6-flash';   // vydán 21. 7. 2026
  static const String flashLite3_5 = 'gemini-3.5-flash-lite';
  static const String flashLite3_1 = 'gemini-3.1-flash-lite'; // vypíná se 7. 5. 2027
  static const String pro3_1 = 'gemini-3.1-pro-preview';

  /// Model pro přesný přepis audia (Speech-to-Text) s časovými značkami slov a detekcí jazyka.
  static const String transcribe = 'gemini-3.5-transcribe';

  /// Model pro živý přepis audia přes WebSockets v reálném čase.
  static const String transcribeLive = 'gemini-3.5-transcribe-live';

  /// Model pro syntézu přirozené řeči (Text-to-Speech). Text čte doslova, vrací WAV (24 kHz).
  static const String tts = 'gemini-3.8-flash-tts';
  /// Rychlejší a levnější záložní TTS (modely 2.5 TTS se vypínají 17. 11. 2026).
  static const String ttsLite = 'gemini-3.8-flash-lite-tts';

  // --- Model pro Multimodal Live API (WebSocket / Voice Tutor) ---
  /// Model optimalizovaný pro real-time dialog a voice-first AI aplikace.
  /// Nativní A2A (audio-to-audio) s nízkou latencí a vyšší kvalitou porozumění.
  static const String liveVoiceModel = 'gemini-3.8-live';
  static const String liveExtendedVoiceModel = 'gemini-3.8-live-extended-thinking';
  
  /// Výchozí model používaný pro hlasového tutora.
  static const String defaultLiveModel = liveVoiceModel;

  /// Model pro generování multimodálních embeddingů (text, obraz, audio, video).
  static const String embedding = 'gemini-embedding-2';

  /// Výchozí model pro standardní textový chat.
  /// gemini-3.8-flash: vydán 2. 9. 2026, nejinteligentnější Flash model optimalizovaný pro
  /// software engineering a agentní workflows.
  static const String defaultModel = flash3_8;

  /// Seznam modelů, které si uživatel může vybrat v nastavení pro textový chat.
  static const List<String> allowedChatModels = [
    argon4,
    flash3_8,
    flash3_6,
    flashLite3_5,
    flashLite3_1,
    pro3_1,
  ];

  /// Vrátí přehledný český název modelu pro zobrazení v UI.
  static String getLabel(String model) {
    switch (model) {
      case argon4:
        return 'Gemini 4 Argon (Vlajková loď 🚀)';
      case flash3_8:
        return 'Gemini 3.8 Flash (Nejnovější ✨)';
      case flash3_6:
        return 'Gemini 3.6 Flash (Stabilní)';
      case flashLite3_5:
        return 'Gemini 3.5 Flash-Lite (Úsporný)';
      case flashLite3_1:
        return 'Gemini 3.1 Flash-Lite (Záložní)';
      case pro3_1:
        return 'Gemini 3.1 Pro (Expertní úvahy 🧠)';
      case liveVoiceModel:
        return 'Gemini 3.8 Live (Hlasový)';
      case liveExtendedVoiceModel:
        return 'Gemini 3.8 Live Extended (Hlasový s úvahami)';
      case transcribe:
        return 'Gemini 3.5 Transcribe (Přepis)';
      case tts:
        return 'Gemini 3.8 Flash TTS (Výslovnost)';
      case ttsLite:
        return 'Gemini 3.8 Flash-Lite TTS';
      default:
        return model;
    }
  }
}
