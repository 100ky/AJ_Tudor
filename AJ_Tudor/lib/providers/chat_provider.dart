import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';
import '../services/tutor_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

final tutorServiceProvider = Provider<TutorService?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) return null;
  return TutorService(apiKey: apiKey);
});

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    return [
      ChatMessage(text: 'Hello! I am your English tutor. How are you doing today?', isUser: false),
    ];
  }

  Future<void> sendMessage(String text) async {
    final userMessage = ChatMessage(text: text, isUser: true);
    state = [...state, userMessage];

    final tutorService = ref.read(tutorServiceProvider);
    if (tutorService == null) {
      state = [...state, ChatMessage(text: 'Chyba: API klíč není nastaven. Zadejte ho prosím v nastavení.', isUser: false)];
      return;
    }

    final responseText = await tutorService.sendMessage(text);
    if (responseText != null) {
      state = [...state, ChatMessage(text: responseText, isUser: false)];
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(() {
  return ChatNotifier();
});
