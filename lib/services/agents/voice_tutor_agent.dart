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

/// Výčet stavů, ve kterých se může Voice Tutor nacházet.
enum TutorState { 
  /// Neaktivní stav (hovor neprobíhá).
  idle, 
  /// Probíhá navazování spojení se serverem.
  connecting, 
  /// Spojení spadlo a probíhá pokus o jeho obnovení.
  reconnecting, 
  /// Aktivní poslech studenta (mikrofon nahrává).
  listening, 
  /// Model zpracovává vstup a přemýšlí nad odpovědí.
  thinking, 
  /// Model zrovna mluví (přehrává se audio).
  speaking, 
  /// Nastala chyba v průběhu lekce.
  error 
}

/// Třída reprezentující jednotlivou zprávu v historii chatu během lekce.
class LiveChatMessage {
  /// Samotný text zprávy.
  final String text;
  /// Příznak, zda zprávu poslal uživatel/student ([true]), nebo tutor ([false]).
  final bool isUser;

  /// Vytvoří instanci zprávy.
  LiveChatMessage(this.text, {required this.isUser});
}

/// Třída držící kompletní stav hlasového sezení.
class VoiceTutorState {
  /// Aktuální stav tutora (idle, listening, speaking atd.).
  final TutorState status;
  /// Průběžný přepis mluveného slova tutora pro aktuální repliku.
  final String currentTranscript;
  /// Kompletní historie zpráv (transkriptu) aktuálního sezení.
  final List<LiveChatMessage> messages;
  /// Popis chybové zprávy, pokud nastala chyba.
  final String errorMessage;
  /// ID vybraného scénáře, který se právě procvičuje.
  final int? selectedScenarioId;
  /// Kontext/Role-play instrukce pro vybraný scénář.
  final String? scenarioContext;

  /// Vytvoří výchozí nebo specifický stav Voice Tutora.
  VoiceTutorState({
    this.status = TutorState.idle,
    this.currentTranscript = '',
    this.messages = const [],
    this.errorMessage = '',
    this.selectedScenarioId,
    this.scenarioContext,
  });

  /// Vytvoří kopii aktuálního stavu s modifikovanými vlastnostmi.
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

/// Státový agent (Notifier) řídící kompletní hlasovou konverzaci s tutorem.
/// 
/// Integruje WebSocket klienta, mikrofonní audio vstup, audio playback,
/// správu stavu aplikace (např. uspání displeje, přechod na pozadí)
/// a asynchronní spouštění vyhodnocení lekce po jejím skončení.
class VoiceTutorAgent extends Notifier<VoiceTutorState> with WidgetsBindingObserver {
  Timer? _thinkingTimer;
  Timer? _watchdogTimer;
  Timer? _stuckTimer;
  int? _currentSessionId;
  bool _isStopping = false;

  late final WakelockService _wakelock;
  late final AudioSessionController _audio;
  late final SessionRepository _repo;
  late final MemoryManagerAgent _memory;

  @override
  VoiceTutorState build() {
    // Inicializace závislých služeb přes Riverpod
    _wakelock = ref.read(wakelockServiceProvider);
    _audio = ref.read(audioSessionControllerProvider);
    _repo = ref.read(sessionRepositoryProvider);
    _memory = ref.read(memoryManagerAgentProvider);

    // Registrace do životního cyklu aplikace (pro detekci pozadí/popředí)
    WidgetsBinding.instance.addObserver(this);

    // Hlídání změn nastavení v reálném čase.
    // Pokud se během hovoru změní API klíč, model nebo hlas, z bezpečnostních důvodů hovor ukončíme.
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
    ref.listen(voiceProvider, (previous, next) {
      if (previous != next && state.status != TutorState.idle) {
        stopSession('voice changed');
      }
    });

    // Cleanup při zničení (dispose) provideru
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      
      // Zrušení všech běžících časovačů
      _watchdogTimer?.cancel();
      _thinkingTimer?.cancel();
      _stuckTimer?.cancel();
      
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
    // Pokud se aplikace vrátí z pozadí (resumed) a probíhá hovor, zkontrolujeme stav WebSocketu.
    // Pokud je socket odpojen, přepneme stav na reconnecting a vynutíme reconnect.
    if (state == AppLifecycleState.resumed) {
      final client = ref.read(geminiLiveClientProvider);
      if (client != null && this.state.status != TutorState.idle && this.state.status != TutorState.error) {
        if (!client.isConnected) {
          L.w('Detekováno odpojení po resume, zkouším reconnect...');
          this.state = this.state.copyWith(status: TutorState.reconnecting);
          client.disconnect();
        }
      }
    }
  }

  /// Nastaví aktivní scénář a jeho roli pro aktuální lekci.
  void selectScenario(int id, String context) {
    state = state.copyWith(selectedScenarioId: id, scenarioContext: context);
  }

  /// Zahájí novou hlasovou lekci.
  /// 
  /// 1. Nastaví stav na `connecting`, zablokuje zhasínání displeje.
  /// 2. Založí nový záznam sezení (session) v lokální databázi.
  /// 3. Načte z databáze briefing/paměť z minulé lekce a připojí jej k systémovému promptu.
  /// 4. Připojí WebSocket klienta k Gemini Live API a zaregistruje callbacky.
  /// 5. Inicializuje mikrofon a spustí nahrávání audia.
  Future<void> startSession() async {
    state = state.copyWith(
      status: TutorState.connecting, 
      errorMessage: '',
      messages: [],
      currentTranscript: '',
    );
    HapticFeedback.mediumImpact();
    _wakelock.enable(); // Zabrání uspání displeje během konverzace
    
    final client = ref.read(geminiLiveClientProvider);
    
    if (client == null) {
      state = state.copyWith(
        status: TutorState.error, 
        errorMessage: 'Chybí API klíč. Nastavte jej v Settings.'
      );
      return;
    }

  L.i('Zahajuji startSession...');

    try {
      // 0. Založení nového sezení v databázi přes repozitář
      final Result<int> sessionResult = await _repo.startNewSession();
      if (sessionResult.isFailure) {
        state = state.copyWith(
          status: TutorState.error, 
          errorMessage: sessionResult.getOrThrow().toString()
        ); 
        return; 
      }
      _currentSessionId = sessionResult.getOrThrow();

      // 1. Příprava dat a promptu pro AI
      final Result<String?> briefingResult = await _repo.getLatestBriefing();
      final lastBriefing = briefingResult.fold((s) => s, (f) => null);
      
      final userProfile = await _repo.getUserProfile();
      final targetLevel = userProfile?.targetLevel ?? 'B1';
      final voice = ref.read(voiceProvider);
      final isImmersive = ref.read(immersiveModeProvider);
      
      // Sestavení dynamického promptu
      var systemPrompt = SystemPromptBuilder.buildTutorPrompt(
        scenarioContext: state.scenarioContext,
        targetLevel: targetLevel,
        isImmersive: isImmersive,
      );
      
      // Pokud máme uloženou paměť z minula, připojíme ji
      if (lastBriefing != null && lastBriefing.isNotEmpty) {
        systemPrompt += '\nKONTEXT Z MINULÉ LEKCE (PAMĚŤ): $lastBriefing\n';
      }
      
      const liveModelName = 'models/${GeminiModels.defaultLiveModel}';
      
      // Spuštění WebSocket připojení
      client.connect(
        modelName: liveModelName,
        systemPrompt: systemPrompt,
        voiceName: voice,
      );

      // Zaregistrování callbacků pro zpracování zpráv z klienta
      _setupClientCallbacks(client, _repo);

      // 2. Aktivace nahrávání mikrofonu
      try {
        await _audio.start(onAudioChunk: (data) {
          // Audio odesíláme pouze tehdy, když aktivně nasloucháme studentovi
          if (state.status == TutorState.listening) {
            client.sendAudioChunk(data);
          }
        });
      } catch (audioError, stack) {
        L.e('Chyba mikrofonu', audioError, stack);
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

  /// Zaregistruje všechny události příchozí z WebSocket klienta Gemini.
  void _setupClientCallbacks(GeminiLiveClient client, SessionRepository repo) {
    // Příjem textové části odpovědi AI
    client.onTextReceived = (text) {
      _resetWatchdog();
      _resetStuckTimer();
      L.i('Text z Gemini: $text');
      state = state.copyWith(
        status: TutorState.speaking,
        // Postupně lepíme přicházející textové kousky k sobě
        currentTranscript: state.currentTranscript + text,
      );
    };

    // Příjem dokončeného přepisu řeči uživatele (Speech-to-Text)
    client.onUserTranscriptReceived = (text) {
      _resetWatchdog();
      HapticFeedback.lightImpact();
      L.i('Uživatel řekl: "$text"');
      
      final newMessages = List<LiveChatMessage>.from(state.messages)
        ..add(LiveChatMessage(text, isUser: true));
      state = state.copyWith(messages: newMessages);
      
      // Uložení přepisu řeči uživatele do historie sezení v DB
      if (_currentSessionId != null) {
        repo.addTranscript(
          sessionId: _currentSessionId!,
          speaker: 'user',
          content: text,
        );
      }
    };

    // Detekce, že začala téct audio data z AI
    client.onAudioReceived = () {
      _resetWatchdog();
      _resetStuckTimer();
      if (state.status != TutorState.speaking) {
        state = state.copyWith(status: TutorState.speaking);
      }
    };

    // Konec promluvy tutora (turn complete)
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

        // Uložení finálního přepisu řeči tutora do DB
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

    // Zpracování logování chyb přes Function Calling
    client.onToolCall = (name, args) {
      if (name == 'log_error' && _currentSessionId != null) {
        repo.addErrorLog(
          sessionId: _currentSessionId!,
          errorType: args['error_type'] ?? 'grammar',
          userSaid: args['user_said'] ?? '',
          correctForm: args['correct_form'] ?? '',
          explanation: args['explanation'] ?? '',
        );
        L.i('✅ Chyba zalogována v reálném čase přes Function Calling.');
      }
    };

    // Změna stavu připojení na síťové vrstvě
    client.onConnectionStatusChanged = (isConnected) {
      if (!isConnected && state.status != TutorState.idle && state.status != TutorState.error && !_isStopping) {
        L.w('Spojení ztraceno během hovoru, přepínám na reconnecting...');
        state = state.copyWith(status: TutorState.reconnecting);
      } else if (isConnected && state.status == TutorState.reconnecting) {
        L.i('Spojení obnoveno, vracím se do stavu listening.');
        state = state.copyWith(status: TutorState.listening);
      }
    };

    // Příjem chybové zprávy z WebSocketu
    client.onError = (error) {
      state = state.copyWith(status: TutorState.error, errorMessage: error);
    };
  }

  /// Bezpečně ukončí aktuální hlasové sezení a spustí asynchronní vyhodnocení.
  /// 
  /// [reason] označuje důvod odpojení (pro účely logování).
  Future<void> stopSession([String reason = 'unknown']) async {
    if (_isStopping) return;
    L.i('Ukončování session (Důvod: $reason)');
    _isStopping = true;
    
    try {
      // Zrušení časovačů
      _thinkingTimer?.cancel();
      _watchdogTimer?.cancel();
      _stuckTimer?.cancel();
      
      _wakelock.disable(); // Povolíme opětovné zhasínání displeje

      // Zastavení mikrofonu
      try {
        await _audio.stop();
      } catch (e, stack) {
        L.e('Chyba při zastavování audia', e, stack);
      }
      
      // Odpojení WebSocket klienta
      if (ref.mounted) {
        try {
          ref.read(geminiLiveClientProvider)?.disconnect();
        } catch (e, stack) {
          L.e('Chyba při odpojování WebSocketu', e, stack);
        }
      }

      // Dokončení rozpracované DB transakce a spuštění analýzy
      if (_currentSessionId != null) {
        final sessionId = _currentSessionId!;
        
        // Pokud model zrovna mluvil a nestihl odeslat turnComplete, flushneme rozpracovaný text
        if (state.currentTranscript.isNotEmpty) {
          final tutorText = state.currentTranscript;
          L.i('Flush: Ukládám zbývající transkript tutora: "$tutorText"');
          try {
            await _repo.addTranscript(
              sessionId: sessionId,
              speaker: 'tutor',
              content: tutorText,
            );
          } catch (e, stack) {
            L.e('Chyba při flushování transkriptu', e, stack);
          }
        }

        L.i('Ukládám a uzavírám session $sessionId');
        try {
          await _repo.closeSession(sessionId);
        } catch (e, stack) {
          L.e('Chyba při uzavírání session', e, stack);
        }
        
        _currentSessionId = null;
        
        // Spuštění asynchronní Structured Outputs analýzy na pozadí přes MemoryManagerAgent
        _memory.analyzeSession(sessionId).catchError((e, stack) {
          L.e('Chyba při spouštění analýzy na pozadí', e, stack);
        });
      }
    } catch (globalError, stack) {
      L.e('Neočekávaná chyba při ukončování session', globalError, stack);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(status: TutorState.idle, currentTranscript: '');
        L.i('UI resetováno do stavu idle');
      }
      _isStopping = false;
    }
  }

  /// Odešle manuální textovou zprávu namísto mluvení (podpora chat režimu).
  void sendText(String text) {
    if (text.trim().isEmpty) return;
    
    _resetWatchdog();
    final client = ref.read(geminiLiveClientProvider);
    if (client != null && state.status != TutorState.idle && state.status != TutorState.error) {
      final newMessages = List<LiveChatMessage>.from(state.messages)
        ..add(LiveChatMessage(text, isUser: true));
      
      // Přepneme stav do 'thinking', dokud AI neodpoví
      state = state.copyWith(messages: newMessages, status: TutorState.thinking);
      client.sendText(text);
    }
  }

  /// Resetuje watchdog časovač aktivity.
  /// 
  /// Pokud 45 sekund nedojde k žádné komunikaci (uživatel ani AI neposílají zprávy/audio),
  /// watchdog automaticky usoudí, že došlo k tichému rozpadu socketu a vyvolá reconnect.
  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 45), () {
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

  /// Resetuje a konfiguruje stuck timer pro stav 'speaking'.
  /// 
  /// Pokud se tutor přepne do stavu `speaking` (má mluvit), ale během 10 sekund
  /// nedorazí žádný další audio chunk ani turnComplete signál, stuck timer
  /// vrátí tutora zpět do stavu `listening`, aby se konverzace neodepsala.
  void _resetStuckTimer() {
    _stuckTimer?.cancel();
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

/// Poskytuje globální instanci [VoiceTutorAgent] a její stav pro UI.
final voiceTutorAgentProvider = NotifierProvider<VoiceTutorAgent, VoiceTutorState>(VoiceTutorAgent.new);
