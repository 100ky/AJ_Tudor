import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/models/chat_message.dart';
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
  /// Konverzace je pozastavena (mikrofon neaktivní, WebSocket zůstává otevřený).
  paused,
  /// Nastala chyba v průběhu lekce.
  error 
}

/// Třída držící kompletní stav hlasového sezení.
class VoiceTutorState {
  /// Aktuální stav tutora (idle, listening, speaking atd.).
  final TutorState status;
  /// Průběžný přepis mluveného slova tutora pro aktuální repliku.
  final String currentTranscript;
  /// Kompletní historie zpráv (transkriptu) aktuálního sezení.
  final List<ChatMessage> messages;
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
    List<ChatMessage>? messages,
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
  Timer? _watchdogTimer;
  Timer? _stuckTimer;
  int? _currentSessionId;
  bool _isStopping = false;

  // Průběžný nashromážděný přepis řeči uživatele pro aktuální repliku.
  String _currentUserTranscript = '';

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
    if (id == 0 || context.trim().isEmpty) {
      state = state.copyWith(selectedScenarioId: null, scenarioContext: null);
    } else {
      state = state.copyWith(selectedScenarioId: id, scenarioContext: context);
    }
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
      _currentUserTranscript = '';

      // Pokud máme vybraný scénář, označíme ho jako použitý v databázi
      if (state.selectedScenarioId != null) {
        await _repo.markScenarioUsed(state.selectedScenarioId!);
      }

      // 1. Příprava dat a promptu pro AI – načtení KOMPLETNÍHO profilu studenta
      final userProfile = await _repo.getUserProfile();
      final targetLevel = userProfile?.targetLevel ?? 'B1';
      final voice = ref.read(voiceProvider);
      final isImmersive = ref.read(immersiveModeProvider);
      
      // Získáme náhodný osobní fakt pro zamezení opakování úvodu
      final personalFact = SystemPromptBuilder.getRandomPersonalFact();

      // Sestavení dynamického promptu s kompletním kontextem z profilu
      final systemPrompt = SystemPromptBuilder.buildTutorPrompt(
        scenarioContext: state.scenarioContext,
        targetLevel: targetLevel,
        isImmersive: isImmersive,
        recurringErrors: userProfile?.recurringErrors,
        vocabulary: userProfile?.vocabulary,
        recentTopics: userProfile?.topicPreferences,
        memoryBriefing: userProfile?.memoryBriefing,
        personalFact: personalFact,
      );
      
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
          // ECHO LOOP OCHRANA: Audio odesíláme POUZE ve stavu listening.
          // Když model mluví (speaking) nebo je pauza, mikrofon data zahazuje.
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

      // Aktivně spustíme konverzaci ze strany AI zasláním skrytého inicializačního textu
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!ref.mounted) return;
        final currentClient = ref.read(geminiLiveClientProvider);
        if (currentClient != null && currentClient.isConnected && state.status == TutorState.listening) {
          state = state.copyWith(status: TutorState.thinking);
          
          String initialPrompt = "Hello! Please greet me and start the conversation according to your instructions.";
          final briefing = userProfile?.memoryBriefing;
          if (state.scenarioContext != null) {
            initialPrompt += " Introduce the role-play scenario and immediately start playing your role.";
          } else if (briefing != null && briefing.isNotEmpty) {
            initialPrompt += " Refer briefly to our last lesson and follow up on the recommended topic or question.";
          } else {
            initialPrompt += " Start with a casual and warm greeting as a friend (do NOT introduce yourself, say your name or where you are from). Share a small, natural detail about your day or mood (following your system instructions example) and ask how my day is going.";
          }
          currentClient.sendText(initialPrompt);
        }
      });
      
    } catch (e, stack) {
      L.e('Chyba startu session', e, stack);
      state = state.copyWith(status: TutorState.error, errorMessage: 'Neočekávaná chyba při startu: $e');
    }
  }

  /// Uloží nashromážděný transkript řeči uživatele do databáze a vymaže ho z paměti.
  void _flushUserTranscript() {
    if (_currentUserTranscript.trim().isNotEmpty) {
      final userText = _currentUserTranscript.trim();
      final sessionId = _currentSessionId;
      _currentUserTranscript = '';
      
      if (sessionId != null) {
        L.i('Ukládám nashromážděný transkript uživatele do DB: "$userText"');
        _repo.addTranscript(
          sessionId: sessionId,
          speaker: 'user',
          content: userText,
        );
      }
    }
  }

  /// Zaregistruje všechny události příchozí z WebSocket klienta Gemini.
  void _setupClientCallbacks(GeminiLiveClient client, SessionRepository repo) {
    // Příjem textové části odpovědi AI
    client.onTextReceived = (text) {
      _flushUserTranscript();
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
      
      final trimmedText = text.trim();
      if (trimmedText.isEmpty) return;

      L.i('STT chunk uživatele: "$trimmedText"');
      
      final isNewTurn = _currentUserTranscript.isEmpty;
      
      if (isNewTurn) {
        _currentUserTranscript = text;
      } else {
        // Pokud předchozí nekončí mezerou a nový nezačíná mezerou, přidáme ji
        final needsLeadingSpace = !_currentUserTranscript.endsWith(' ') && !text.startsWith(' ');
        _currentUserTranscript += (needsLeadingSpace ? ' ' : '') + text;
      }

      final displayTranscript = _currentUserTranscript.trim();

      if (isNewTurn) {
        final newMessages = List<ChatMessage>.from(state.messages)
          ..add(ChatMessage(displayTranscript, isUser: true));
        state = state.copyWith(messages: newMessages);
      } else {
        if (state.messages.isNotEmpty && state.messages.last.isUser) {
          final newMessages = List<ChatMessage>.from(state.messages);
          newMessages[newMessages.length - 1] = ChatMessage(displayTranscript, isUser: true);
          state = state.copyWith(messages: newMessages);
        } else {
          final newMessages = List<ChatMessage>.from(state.messages)
            ..add(ChatMessage(displayTranscript, isUser: true));
          state = state.copyWith(messages: newMessages);
        }
      }
    };

    // Detekce, že začala téct audio data z AI
    client.onAudioReceived = () {
      _flushUserTranscript();
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
        
        final newMessages = List<ChatMessage>.from(state.messages)
          ..add(ChatMessage(tutorText, isUser: false));
        
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

    // Zpracování přerušení mluvení modelu uživatelem
    client.onInterrupted = () {
      _resetWatchdog();
      _resetStuckTimer();
      L.i('Model byl přerušen uživatelem.');
      state = state.copyWith(
        status: TutorState.listening,
        currentTranscript: '',
      );
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
        
        // Flush any remaining user transcript
        if (_currentUserTranscript.trim().isNotEmpty) {
          final userText = _currentUserTranscript.trim();
          L.i('Flush: Ukládám zbývající transkript uživatele před koncem session: "$userText"');
          try {
            await _repo.addTranscript(
              sessionId: sessionId,
              speaker: 'user',
              content: userText,
            );
          } catch (e, stack) {
            L.e('Chyba při flushování transkriptu uživatele', e, stack);
          }
          _currentUserTranscript = '';
        }

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
        state = state.copyWith(
          status: TutorState.idle,
          currentTranscript: '',
          selectedScenarioId: null,
          scenarioContext: null,
        );
        L.i('UI resetováno do stavu idle');
      }
      _isStopping = false;
    }
  }

  /// Pozastaví probíhající konverzaci.
  /// 
  /// Zastaví mikrofon, ale ponechá WebSocket otevřený pro rychlé obnovení.
  /// Wakelock zůstává zapnutý, aby se displej nezhasil.
  Future<void> pauseSession() async {
    if (state.status == TutorState.idle || state.status == TutorState.error || state.status == TutorState.paused) return;
    
    L.i('Pozastavuji konverzaci...');
    HapticFeedback.lightImpact();
    
    _flushUserTranscript();
    
    // Zastavíme watchdog a stuck timer, aby nespustily reconnect během pauzy
    _watchdogTimer?.cancel();
    _stuckTimer?.cancel();
    
    // Zastavíme mikrofon, ale necháme WebSocket otevřený
    try {
      await _audio.stop();
    } catch (e) {
      L.w('Chyba při pozastavení mikrofonu: $e');
    }
    
    state = state.copyWith(status: TutorState.paused);
  }

  /// Obnoví pozastavenou konverzaci.
  /// 
  /// Znovu aktivuje mikrofon a vrátí stav do listening.
  Future<void> resumeSession() async {
    if (state.status != TutorState.paused) return;
    
    L.i('Obnovuji konverzaci...');
    HapticFeedback.mediumImpact();
    
    final client = ref.read(geminiLiveClientProvider);
    if (client == null || !client.isConnected) {
      L.w('WebSocket odpojen během pauzy, nelze obnovit.');
      state = state.copyWith(status: TutorState.error, errorMessage: 'Spojení bylo přerušeno během pauzy.');
      return;
    }
    
    // Znovu aktivujeme mikrofon
    try {
      await _audio.start(onAudioChunk: (data) {
        if (state.status == TutorState.listening) {
          client.sendAudioChunk(data);
        }
      });
    } catch (e) {
      L.e('Chyba mikrofonu při obnovení: $e');
      state = state.copyWith(status: TutorState.error, errorMessage: 'Chyba mikrofonu: $e');
      return;
    }
    
    state = state.copyWith(status: TutorState.listening);
    _resetWatchdog();
  }

  /// Odešle manuální textovou zprávu namísto mluvení (podpora chat režimu).
  void sendText(String text) {
    if (text.trim().isEmpty) return;
    
    _resetWatchdog();
    final client = ref.read(geminiLiveClientProvider);
    if (client != null && state.status != TutorState.idle && state.status != TutorState.error && state.status != TutorState.paused) {
      _flushUserTranscript(); // Flush voice transcript if any was in progress
      
      final newMessages = List<ChatMessage>.from(state.messages)
        ..add(ChatMessage(text, isUser: true));
      
      // Přepneme stav do 'thinking', dokud AI neodpoví
      state = state.copyWith(messages: newMessages, status: TutorState.thinking);
      client.sendText(text);

      // Uložení manuálního textu do DB
      if (_currentSessionId != null) {
        _repo.addTranscript(
          sessionId: _currentSessionId!,
          speaker: 'user',
          content: text.trim(),
        );
      }
    }
  }

  /// Resetuje watchdog časovač aktivity.
  /// 
  /// Pokud 45 sekund nedojde k žádné komunikaci (uživatel ani AI neposílají zprávy/audio),
  /// watchdog automaticky usoudí, že došlo k tichému rozpadu socketu a vyvolá reconnect.
  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 45), () {
      if (state.status != TutorState.idle && state.status != TutorState.error && state.status != TutorState.paused) {
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
