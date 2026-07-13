import 'package:google_generative_ai/google_generative_ai.dart';
import 'system_prompt_builder.dart';

class TutorService {
  final String apiKey;
  late GenerativeModel _model;
  late ChatSession _chatSession;

  TutorService({required this.apiKey, String targetLevel = 'B1', String nativeLanguage = 'cs'}) {
    final systemPrompt = SystemPromptBuilder.buildPrompt(targetLevel, nativeLanguage);
    
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Pro text a rychlost použijeme osvědčený model
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );
    
    _chatSession = _model.startChat();
  }

  Future<String?> sendMessage(String text) async {
    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      return response.text;
    } catch (e) {
      return "Omlouvám se, došlo k chybě při komunikaci: $e";
    }
  }
}
