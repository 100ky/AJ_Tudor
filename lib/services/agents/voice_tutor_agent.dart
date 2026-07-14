import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audio_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../prompt/system_prompt_builder.dart';

enum TutorState { idle, connecting, listening, thinking, speaking, error }

class LiveChatMessage {
  final String text;
  final bool isUser;
  LiveChatMessage(this.text, {required this.isUser});
}

class VoiceTutorState {
  final TutorState status;
  final String currentTranscript;
  final List<LiveChatMessage> messages;
  final String errorMessage;

  VoiceTutorState({
    this.status = TutorState.idle,
    this.currentTranscript = '',
    this.messages = const [],
    this.errorMessage = '',
  });

  VoiceTutorState copyWith({
    TutorState? status,
    String? currentTranscript,
    List<LiveChatMessage>? messages,
    String? errorMessage,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class VoiceTutorAgent extends Notifier<VoiceTutorState> {
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _thinkingTimer;

  @override
  VoiceTutorState build() {
    ref.onDispose(() {
      stopSession();
    });
    return VoiceTutorState();
  }

  Future<void> startSession() async {
    state = state.copyWith(status: TutorState.connecting, errorMessage: '');
    
    final client = ref.read(geminiLiveClientProvider);
    final audioCapture = ref.read(audioCaptureServiceProvider);
    
    if (client == null) {
      state = state.copyWith(
        status: TutorState.error, 
        errorMessage: 'Chybí API klíč. Nastavte jej v Settings.'
      );
      return;
    }

    try {
      // 1. Připojení k WebSocketu
      final systemPrompt = SystemPromptBuilder.buildTutorPrompt();
      
      // BidiGenerateContent (Live API) vyžaduje specifické modely pro real-time audio.
      const liveModelName = 'models/${GeminiModels.defaultLiveModel}';
      
      client.connect(modelName: liveModelName, systemPrompt: systemPrompt);

      // Nastavení callbacků
      client.onTextReceived = (text) {
        // Zpracování průběžné transkripce
        state = state.copyWith(
          status: TutorState.speaking,
          currentTranscript: state.currentTranscript + text,
        );
      };

      client.onTurnComplete = () {
        // Po dokončení promluvy uložíme text do historie a vyčistíme aktuální transkripci
        if (state.currentTranscript.isNotEmpty) {
          final newMessages = List<LiveChatMessage>.from(state.messages)
            ..add(LiveChatMessage(state.currentTranscript, isUser: false));
          state = state.copyWith(
            status: TutorState.listening,
            currentTranscript: '',
            messages: newMessages,
          );
        } else {
          state = state.copyWith(status: TutorState.listening);
        }
      };

      client.onError = (error) {
        state = state.copyWith(status: TutorState.error, errorMessage: error);
      };

      // 2. Zahájení nahrávání audia z mikrofonu
      try {
        await audioCapture.startRecording();
        
        _audioSubscription = audioCapture.audioStream.listen((data) {
          // Posíláme data na server, pokud nejsme v idle nebo error stavu.
          if (state.status != TutorState.idle && state.status != TutorState.error) {
            client.sendAudioChunk(data);
          }
        });
      } catch (audioError) {
        state = state.copyWith(
          status: TutorState.error, 
          errorMessage: 'Chyba mikrofonu: $audioError. Zkontrolujte oprávnění v nastavení telefonu.'
        );
        client.disconnect();
        return;
      }

      state = state.copyWith(status: TutorState.listening, currentTranscript: '');
      
    } catch (e) {
      state = state.copyWith(status: TutorState.error, errorMessage: 'Chyba startu session: $e');
    }
  }

  Future<void> stopSession() async {
    _thinkingTimer?.cancel();
    _audioSubscription?.cancel();
    
    ref.read(audioCaptureServiceProvider).stopRecording();
    ref.read(geminiLiveClientProvider)?.disconnect();
    
    state = state.copyWith(status: TutorState.idle, currentTranscript: '');
  }

  void sendText(String text) {
    if (text.trim().isEmpty) return;
    
    final client = ref.read(geminiLiveClientProvider);
    if (client != null && state.status != TutorState.idle && state.status != TutorState.error) {
      final newMessages = List<LiveChatMessage>.from(state.messages)
        ..add(LiveChatMessage(text, isUser: true));
      
      state = state.copyWith(messages: newMessages, status: TutorState.thinking);
      client.sendText(text);
    }
  }
}

final voiceTutorAgentProvider = NotifierProvider<VoiceTutorAgent, VoiceTutorState>(VoiceTutorAgent.new);
