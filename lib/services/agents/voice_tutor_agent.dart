import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audio_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/gemini_provider.dart';
import '../prompt/system_prompt_builder.dart';

enum TutorState { idle, connecting, listening, thinking, speaking, error }

class VoiceTutorState {
  final TutorState status;
  final String currentTranscript;
  final String errorMessage;

  VoiceTutorState({
    this.status = TutorState.idle,
    this.currentTranscript = '',
    this.errorMessage = '',
  });

  VoiceTutorState copyWith({
    TutorState? status,
    String? currentTranscript,
    String? errorMessage,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
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
      // Nelze použít běžný textový model jako gemini-3.5-flash.
      const liveModelName = 'models/gemini-live-2.5-flash-native-audio';
      
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
        // Po dokončení promluvy čekáme na uživatele
        state = state.copyWith(status: TutorState.listening);
      };

      client.onError = (error) {
        state = state.copyWith(status: TutorState.error, errorMessage: error);
      };

      // 2. Zahájení nahrávání audia z mikrofonu
      await audioCapture.startRecording();
      
      _audioSubscription = audioCapture.audioStream.listen((data) {
        client.sendAudioChunk(data);
        
        // Jednoduchá heuréka pro stav "listening" -> "thinking" by vyžadovala VAD (Voice Activity Detection),
        // ale v tuto chvíli necháme stav primárně na listening/speaking
      });

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
    
    state = state.copyWith(status: TutorState.idle);
  }
}

final voiceTutorAgentProvider = NotifierProvider<VoiceTutorAgent, VoiceTutorState>(VoiceTutorAgent.new);
