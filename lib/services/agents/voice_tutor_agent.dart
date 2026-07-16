import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/repositories/session_repository.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../prompt/system_prompt_builder.dart';
import '../audio/audio_session_controller.dart';
import '../system/wakelock_service.dart';
import '../gemini/gemini_live_client.dart';

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
  Timer? _thinkingTimer;
  Timer? _watchdogTimer;
  Timer? _stuckTimer;
  int? _currentSessionId;
  bool _isStopping = false;

  // Odstranění cachovaného _client, budeme ho číst dynamicky
  late final WakelockService _wakelock;
  late final AudioSessionController _audio;
  late final SessionRepository _repo;
  late final MemoryManagerAgent _memory;

  @override
  VoiceTutorState build() {
    _wakelock = ref.read(wakelockServiceProvider);
    _audio = ref.read(audioSessionControllerProvider);
    _repo = ref.read(sessionRepositoryProvider);
    _memory = ref.read(memoryManagerAgentProvider);

    // Registrace observeru životního cyklu
    WidgetsBinding.instance.addObserver(this);

    // Pokud se změní API klíč nebo model, ukončíme aktivní hovor
    ref.listen(apiKeyProvider, (previous, next) {
      if (previous != next && state.status != TutorState.idle) {
        stopSession('apiKey changed');
      }
    });
    ref.listen(modelProvider, (previous, next) {
      if (previous != next && state.status != TutorState.idle) {
        stopSession('model changed');
      }
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      
      // Synchronní část cleanupu
      _watchdogTimer?.cancel();
      _thinkingTimer?.cancel();
      _stuckTimer?.cancel();
      
      // Pro asynchronní cleanup v onDispose musíme být opatrní s ref.read.
      // Raději zavoláme stopSession, ale zachytíme chyby Riverpodu při disposal.
      try {
        stopSession('disposed');
      } catch (e) {
        L.w('Chyba při disposal VoiceTutorAgent: $e');
      }
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
          client.disconnect();
        }
      }
    }
  }

  void selectScenario(int id, String context) {
    state = state.copyWith(selectedScenarioId: id, scenarioContext: context);
  }

  Future<void> startSession() async {
    state = state.copyWith(
      status: TutorState.connecting, 
      errorMessage: '',
      messages: [],
      currentTranscript: '',
    );
    HapticFeedback.mediumImpact();
    _wakelock.enable();
    
    final client = ref.read(geminiLiveClientProvider);
    
    if (client == null) {
      state = state.copyWith(
        status: TutorState.error, 
        errorMessage: 'Chybí API klíč. Nastavte jej v Settings.'
      );
      return;
    }

    try {
      // 0. Založení session
      final Result<int> sessionResult = await _repo.startNewSession();
      if (sessionResult.isFailure) {
        state = state.copyWith(status: TutorState.error, errorMessage: sessionResult.getOrThrow().toString()); 
        return; 
      }
      _currentSessionId = sessionResult.getOrThrow();

      // 1. Připojení k AI
      final Result<String?> briefingResult = await _repo.getLatestBriefing();
      final lastBriefing = briefingResult.fold((s) => s, (f) => null);
      
      final userProfile = await _repo.getUserProfile();
      final targetLevel = userProfile?.targetLevel ?? 'B1';
      
      var systemPrompt = SystemPromptBuilder.buildTutorPrompt(
        scenarioContext: state.scenarioContext,
        targetLevel: targetLevel,
      );
      
      if (lastBriefing != null && lastBriefing.isNotEmpty) {
        systemPrompt += '\nKONTEXT Z MINULÉ LEKCE (PAMĚŤ): $lastBriefing\n';
      }
      
      const liveModelName = 'models/${GeminiModels.defaultLiveModel}';
      client.connect(modelName: liveModelName, systemPrompt: systemPrompt);

      _setupClientCallbacks(client, _repo);

      // 2. Audio
      try {
        await _audio.start(onAudioChunk: (data) {
          if (state.status == TutorState.listening) {
            client.sendAudioChunk(data);
          }
        });
      } catch (audioError) {
        state = state.copyWith(
          status: TutorState.error, 
          errorMessage: 'Chyba mikrofonu: $audioError'
        );
        client.disconnect();
        return;
      }

      state = state.copyWith(status: TutorState.listening, currentTranscript: '');
      _resetWatchdog();
      
    } catch (e, stack) {
      L.e('Chyba startu session', e, stack);
      state = state.copyWith(status: TutorState.error, errorMessage: 'Neočekávaná chyba při startu: $e');
    }
  }

  void _setupClientCallbacks(GeminiLiveClient client, SessionRepository repo) {
    client.onTextReceived = (text) {
      _resetWatchdog();
      _resetStuckTimer();
      L.i('Text z Gemini: $text');
      state = state.copyWith(
        status: TutorState.speaking,
        currentTranscript: state.currentTranscript + text,
      );
    };

    client.onUserTranscriptReceived = (text) {
      _resetWatchdog();
      HapticFeedback.lightImpact();
      L.i('Uživatel řekl: "$text"');
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
      _resetWatchdog();
      _resetStuckTimer();
      if (state.status != TutorState.speaking) {
        state = state.copyWith(status: TutorState.speaking);
      }
    };

    client.onTurnComplete = () {
      _resetWatchdog();
      HapticFeedback.selectionClick();
      if (state.currentTranscript.isNotEmpty) {
        final tutorText = state.currentTranscript;
        L.i('Tutor řekl: "$tutorText"');
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
        L.i('✅ Chyba zalogována přes Function Calling.');
      }
    };

    client.onConnectionStatusChanged = (isConnected) {
      if (!isConnected && state.status != TutorState.idle && state.status != TutorState.error && !_isStopping) {
        L.w('Spojení ztraceno během hovoru, přepínám na reconnecting...');
        state = state.copyWith(status: TutorState.reconnecting);
      } else if (isConnected && state.status == TutorState.reconnecting) {
        L.i('Spojení obnoveno, vracím se do stavu listening.');
        state = state.copyWith(status: TutorState.listening);
      }
    };

    client.onError = (error) {
      state = state.copyWith(status: TutorState.error, errorMessage: error);
    };
  }

  Future<void> stopSession([String reason = 'unknown']) async {
    if (_isStopping) return;
    L.i('Ukončování session (Důvod: $reason)');
    _isStopping = true;
    
    try {
      _thinkingTimer?.cancel();
      _watchdogTimer?.cancel();
      _stuckTimer?.cancel();
      
      _wakelock.disable();

      try {
        await _audio.stop();
      } catch (e) {
        L.e('Chyba při zastavování audia', e);
      }
      
      if (ref.mounted) {
        try {
          ref.read(geminiLiveClientProvider)?.disconnect();
        } catch (e) {
          L.e('Chyba při odpojování WebSocketu', e);
        }
      }

      if (_currentSessionId != null) {
        final sessionId = _currentSessionId!;
        
        if (state.currentTranscript.isNotEmpty) {
          final tutorText = state.currentTranscript;
          L.i('Flush: Ukládám zbývající transkript tutora: "$tutorText"');
          try {
            await _repo.addTranscript(
              sessionId: sessionId,
              speaker: 'tutor',
              content: tutorText,
            );
          } catch (e) {
            L.e('Chyba při flushování transkriptu', e);
          }
        }

        L.i('Ukládám a analyzuji session $sessionId');
        try {
          await _repo.closeSession(sessionId);
        } catch (e) {
          L.e('Chyba při uzavírání session', e);
        }
        
        _currentSessionId = null;
        
        _memory.analyzeSession(sessionId).catchError((e) {
          L.e('Chyba při spouštění analýzy na pozadí', e);
        });
      }
    } catch (globalError) {
      L.e('Neočekávaná chyba při ukončování session', globalError);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(status: TutorState.idle, currentTranscript: '');
        L.i('UI resetováno do stavu idle');
      }
      _isStopping = false;
    }
  }

  void sendText(String text) {
    if (text.trim().isEmpty) return;
    
    _resetWatchdog();
    final client = ref.read(geminiLiveClientProvider);
    if (client != null && state.status != TutorState.idle && state.status != TutorState.error) {
      final newMessages = List<LiveChatMessage>.from(state.messages)
        ..add(LiveChatMessage(text, isUser: true));
      
      state = state.copyWith(messages: newMessages, status: TutorState.thinking);
      client.sendText(text);
    }
  }

  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 45), () { // Prodlouženo na 45s
      if (state.status != TutorState.idle && state.status != TutorState.error) {
        L.w('Watchdog: Žádná aktivita 45s, zkouším reconnect...');
        if (ref.mounted) {
          final client = ref.read(geminiLiveClientProvider);
          if (client != null) {
            state = state.copyWith(status: TutorState.reconnecting);
            client.forceReconnect();
          }
        }
      }
    });
  }

  void _resetStuckTimer() {
    _stuckTimer?.cancel();
    // Pokud je stav 'speaking', nastavíme timeout na 10 sekund.
    // Pokud během 10s nepřijde ani kousek audia nebo textu, přepneme zpět na 'listening'.
    if (state.status == TutorState.speaking) {
      _stuckTimer = Timer(const Duration(seconds: 10), () {
        if (state.status == TutorState.speaking) {
          L.w('Detekováno zaseknutí ve stavu speaking (10s ticho), vracím do listening.');
          state = state.copyWith(status: TutorState.listening);
        }
      });
    }
  }
}

final voiceTutorAgentProvider = NotifierProvider<VoiceTutorAgent, VoiceTutorState>(VoiceTutorAgent.new);
