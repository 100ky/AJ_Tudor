class GeminiModels {
  // Rychlé modely pro běžný chat a připravované Live API
  static const String flash3_5 = 'gemini-3.5-flash';
  static const String flash2 = 'gemini-2.0-flash';
  static const String flash1_5 = 'gemini-1.5-flash';
  
  // Pokročilé modely pro složitější analytické úlohy (v budoucnu pro Memory Manager)
  static const String pro1_5 = 'gemini-1.5-pro';

  // Specializované modely
  static const String embedding = 'text-embedding-004';

  // Seznam povolených modelů pro textový chat v nastavení
  static const List<String> allowedChatModels = [
    flash3_5,
    flash2,
    flash1_5,
    pro1_5,
  ];

  static String getLabel(String model) {
    switch (model) {
      case flash3_5:
        return 'Gemini 3.5 Flash (Nejnovější textový)';
      case flash2:
        return 'Gemini 2.0 Flash (Nejrychlejší)';
      case flash1_5:
        return 'Gemini 1.5 Flash (Stabilní)';
      case pro1_5:
        return 'Gemini 1.5 Pro (Pokročilý)';
      default:
        return model;
    }
  }
}
