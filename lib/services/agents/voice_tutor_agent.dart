import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/audio_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../prompt/system_prompt_builder.dart';

import 'memory_manager_agent.dart';

enum TutorState { idle, connecting, reconnecting, listening, thinking, speaking, error }

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
  final int? selectedScenarioId;
  final String? scenarioContext;

  VoiceTutorState({
    this.status = TutorState.idle,
    this.currentTranscript = '',
    this.messages = const [],
    this.errorMessage = '',
    this.selectedScenarioId,
    this.scenarioContext,
  });

  VoiceTutorState copyWith({
    TutorState? status,
    String? currentTranscript,
    List<LiveChatMessage>? messages,
    String? errorMessage,
    int? selectedScenarioId,
    String? scenarioContext,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedScenarioId: selectedScenarioId ?? this.selectedScenarioId,
      scenarioContext: scenarioContext ?? this.scenarioContext,
    );
  }
}

class VoiceTutorAgent extends Notifier<VoiceTutorState> with WidgetsBindingObserver {
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _thinkingTimer;
  int? _currentSessionId;

  @override
  VoiceTutorState build() {
    // Registrace observeru životního cyklu
    WidgetsBinding.instance.addObserver(this);

    // Pokud se změní API klíč nebo model, ukončíme aktivní hovor
    ref.listen(apiKeyProvider, (previous, next) {
      if (state.status != TutorState.idle) stopSession();
    });
    ref.listen(modelProvider, (previous, next) {
      if (state.status != TutorState.idle) stopSession();
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      stopSession();
    });
    return VoiceTutorState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pokud se aplikace vrátí z pozadí a probíhá hovor, zkontrolujeme spojení
    if (state == AppLifecycleState.resumed) {
      final client = ref.read(geminiLiveClientProvider);
      if (client != null && this.state.status != TutorState.idle && this.state.status != TutorState.error) {
        if (!client.isConnected) {
          debugPrint('Detekováno odpojení po resume, zkouším reconnect...');
          this.state = this.state.copyWith(status: TutorState.reconnecting);
          // GeminiLiveClient má interní reconnect logiku na onDone/onError, 
          // ale po resume může být socket "zombie".
          client.disconnect(); // Tím vyvoláme onDone a následný auto-reconnect
        }
      }
    }
  }

  void selectScenario(int id, String context) {
    state = state.copyWith(selectedScenarioId: id, scenarioContext: context);
  }

  Future<void> startSession() async {
    // Při startu nové session vyčistíme zprávy z té předchozí v UI
    state = state.copyWith(
      status: TutorState.connecting, 
      errorMessage: '',
      messages: [],
      currentTranscript: '',
    );
    HapticFeedback.mediumImpact();
    
    // Aktivace wakelocku
    WakelockPlus.enable();
    
    final client = ref.read(geminiLiveClientProvider);
    final audioCapture = ref.read(audioCaptureServiceProvider);
    final repo = ref.read(sessionRepositoryProvider);
    
    if (client == null) {
      state = state.copyWith(
        status: TutorState.error, 
        errorMessage: 'Chybí API klíč. Nastavte jej v Settings.'
      );
      return;
    }

    try {
      // 0. Založení session v databázi
      _currentSessionId = await repo.startNewSession();

      // 1. Připojení k WebSocketu
      // Načteme briefing z minula pro personalizaci
      final lastBriefing = await repo.getLatestBriefing();
      var systemPrompt = SystemPromptBuilder.buildTutorPrompt(
        scenarioContext: state.scenarioContext,
      );
      
      if (lastBriefing != null && lastBriefing.isNotEmpty) {
        systemPrompt += '\nKONTEXT Z MINULÉ LEKCE (PAMĚŤ): $lastBriefing\n';
      }
      
      // Pro hlasový chat vždy vynutíme model, který Bidi protokol (Live API) podporuje.
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

      client.onUserTranscriptReceived = (text) {
        HapticFeedback.lightImpact();
        // Uložení toho, co řekl uživatel, do historie a DB
        final newMessages = List<LiveChatMessage>.from(state.messages)
          ..add(LiveChatMessage(text, isUser: true));
        state = state.copyWith(messages: newMessages);
        
        if (_currentSessionId != null) {
          repo.addTranscript(
            sessionId: _currentSessionId!,
            speaker: 'user',
            content: text,
          );
        }
      };

      client.onAudioReceived = () {
        // Pokud přijímáme zvuk, přepneme stav na speaking (i když nemáme text)
        if (state.status != TutorState.speaking) {
          state = state.copyWith(status: TutorState.speaking);
        }
      };

      client.onTurnComplete = () {
        HapticFeedback.selectionClick();
        // Po dokončení promluvy uložíme text do historie a vyčistíme aktuální transkripci
        if (state.currentTranscript.isNotEmpty) {
          final tutorText = state.currentTranscript;
          final newMessages = List<LiveChatMessage>.from(state.messages)
            ..add(LiveChatMessage(tutorText, isUser: false));
          
          state = state.copyWith(
            status: TutorState.listening,
            currentTranscript: '',
            messages: newMessages,
          );

          if (_currentSessionId != null) {
            repo.addTranscript(
              sessionId: _currentSessionId!,
              speaker: 'tutor',
              content: tutorText,
            );
          }
        } else {
          state = state.copyWith(status: TutorState.listening);
        }
      };

      client.onToolCall = (name, args) {
        if (name == 'log_error' && _currentSessionId != null) {
          repo.addErrorLog(
            sessionId: _currentSessionId!,
            errorType: args['error_type'] ?? 'grammar',
            userSaid: args['user_said'] ?? '',
            correctForm: args['correct_form'] ?? '',
            explanation: args['explanation'] ?? '',
          );
          debugPrint('✅ Chyba zalogována v reálném čase přes Function Calling.');
        }
      };

      client.onConnectionStatusChanged = (isConnected) {
        if (!isConnected && state.status != TutorState.idle && state.status != TutorState.error) {
          state = state.copyWith(status: TutorState.reconnecting);
        } else if (isConnected && state.status == TutorState.reconnecting) {
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
    
    // Deaktivace wakelocku
    WakelockPlus.disable();

    ref.read(audioCaptureServiceProvider).stopRecording();
    ref.read(geminiLiveClientProvider)?.disconnect();

    if (_currentSessionId != null) {
      final sessionId = _currentSessionId!;
      await ref.read(sessionRepositoryProvider).closeSession(sessionId);
      _currentSessionId = null;

      // Spustíme asynchronní analýzu
      ref.read(memoryManagerAgentProvider).analyzeSession(sessionId);
    }
    
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
