import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../../data/models/chat_message.dart';
import '../../services/gemini/gemini_providers.dart';
import '../../services/prompt/system_prompt_builder.dart';
import '../../services/prompt/task_prompts.dart';

/// Stav textového gramatického drilu.
class GrammarDrillState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const GrammarDrillState({this.messages = const [], this.isLoading = false});

  GrammarDrillState copyWith({List<ChatMessage>? messages, bool? isLoading}) {
    return GrammarDrillState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Až 4 opakující se chyby studenta, na které se dril zaměří.
///
/// Sloupec obsahuje JSON pole; starší data mohla být uložena jako text oddělený čárkami.
List<String> drillFocusErrors(String? errorsJson) {
  if (errorsJson == null || errorsJson.isEmpty || errorsJson == '[]') return [];
  try {
    if (errorsJson.startsWith('[')) {
      final list = jsonDecode(errorsJson);
      if (list is List) {
        return list.map((e) => e.toString()).take(4).toList();
      }
    }
  } catch (_) {}
  return errorsJson
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .take(4)
      .toList();
}

/// Gramatický dril: AI vybere slabinu studenta, vysvětlí pravidlo,
/// zadá české věty k překladu a opravuje odpovědi.
class GrammarDrillController extends Notifier<GrammarDrillState> {
  @override
  GrammarDrillState build() {
    // Po změně modelu začne dril nanovo
    ref.listen(modelProvider, (previous, next) {
      if (previous != next) state = state.copyWith(messages: const []);
    });
    return const GrammarDrillState();
  }

  /// Zda je nastavený API klíč.
  bool get hasApiKey => ref.read(geminiBatchClientProvider) != null;

  /// Spustí nový dril – na opakující se chyby, nebo na téma [topicHint].
  Future<void> startDrill([String? topicHint]) async {
    final client = ref.read(geminiBatchClientProvider);
    if (client == null) return;

    final userDisplayText = (topicHint != null && topicHint.isNotEmpty)
        ? 'Procvičit téma: $topicHint'
        : 'Spustit gramatický dril na mé chyby';

    state = GrammarDrillState(
      messages: [ChatMessage(userDisplayText, isUser: true)],
      isLoading: true,
    );

    try {
      final response = await client.sendMessage(
        TaskPrompts.drillKickoff(topicHint),
        systemPrompt: _systemPrompt(),
      );
      if (!ref.mounted) return;
      _addTutorMessage(response);
    } catch (e) {
      if (!ref.mounted) return;
      _addTutorMessage(
          '❌ Nepodařilo se spustit dril: $e\nZkontrolujte připojení nebo zkuste jiné téma.');
    }
  }

  /// Odešle odpověď / dotaz studenta a přidá reakci tutora.
  Future<void> send(String text) async {
    final client = ref.read(geminiBatchClientProvider);
    if (text.isEmpty || client == null) return;

    state = GrammarDrillState(
      messages: [...state.messages, ChatMessage(text, isUser: true)],
      isLoading: true,
    );

    try {
      final response = await client.sendMessage(text, systemPrompt: _systemPrompt());
      if (!ref.mounted) return;
      _addTutorMessage(response);
    } catch (e) {
      if (!ref.mounted) return;
      _addTutorMessage('Chyba při komunikaci: $e');
    }
  }

  /// Vymaže konverzaci drilu.
  void reset() => state = state.copyWith(messages: const []);

  void _addTutorMessage(String text) {
    state = GrammarDrillState(
      messages: [...state.messages, ChatMessage(text, isUser: false)],
      isLoading: false,
    );
  }

  String _systemPrompt() {
    final profile = ref.read(userProfileProvider).value;
    return SystemPromptBuilder.buildGrammarDrillPrompt(
      recurringErrors: profile?.recurringErrors ?? '',
      targetLevel: profile?.targetLevel ?? 'B1',
      vocabulary: profile?.vocabulary,
    );
  }
}

/// Poskytuje [GrammarDrillController].
final grammarDrillControllerProvider =
    NotifierProvider<GrammarDrillController, GrammarDrillState>(GrammarDrillController.new);
