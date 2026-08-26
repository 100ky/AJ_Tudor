import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
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
  Timer? _thinkingTimer;
  Timer? _responseSilenceTimer;
  Timer? _vadSilenceTimer;
  int? _currentSessionId;
  bool _isStopping = false;

  // Průběžný nashromážděný přepis řeči uživatele pro aktuální repliku.
  String _currentUserTranscript = '';
  
  // Heuristiky pro detekci frustrace a stagnace
  int _consecutiveShortAnswers = 0;
  final List<String> _tutorTextHistory = [];
  bool _turnCompleteReceived = false;
  bool _muteLogged = false;
  bool _userSpokeInCurrentTurn = false;

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
      _thinkingTimer?.cancel();
      _responseSilenceTimer?.cancel();
      _vadSilenceTimer?.cancel();
      
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
      if (client != null && this.state.status != TutorState.idle && this.state.status != TutorState.error && this.state.status != TutorState.paused) {
        if (!client.isConnected) {
          L.w('Detekováno odpojení po resume, zkouším obnovit spojení...');
          this.state = this.state.copyWith(status: TutorState.reconnecting);
          client.forceReconnect();
        } else {
          _resetWatchdog();
        }

        // Ověříme, zda mikrofon po návratu z pozadí stále nahrává
        _audio.ensureRecording(onAudioChunk: (data) {
          _handleIncomingAudioChunk(data, client);
        });
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
    if (_currentSessionId != null) {
      L.w('Pokus o startSession, ale předchozí session ($_currentSessionId) nebyla uzavřena. Uzavírám a odesílám k analýze.');
      await stopSession('forced_restart');
    }

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
          _handleIncomingAudioChunk(data, client);
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
          _resetThinkingTimer();
          
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
      
      // --- DETEKCE FRUSTRACE (Krátké odpovědi) ---
      final wordCount = userText.split(RegExp(r'\s+')).where((w) => w.length > 1).length;
      if (wordCount <= 3) {
        _consecutiveShortAnswers++;
        if (_consecutiveShortAnswers >= 3) {
           L.w('Detekována frustrace/nezájem (3x krátká odpověď za sebou). Injektuji afektivní rekalibraci.');
           injectMidSessionGuidance('STUDENT IS GIVING VERY SHORT ANSWERS. They might be frustrated or tired. STOP asking difficult questions. Validate their effort, be extremely encouraging, and switch to a very easy, fun, and relaxing topic immediately.');
           _consecutiveShortAnswers = 0; // reset po injekci
        }
      } else {
        _consecutiveShortAnswers = 0;
      }
      
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
      _responseSilenceTimer?.cancel();
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
      _userSpokeInCurrentTurn = true;
      _resetResponseSilenceTimer();
      HapticFeedback.lightImpact();
      
      if (text.isEmpty) return;

      L.i('STT chunk uživatele: "$text"');
      
      final isNewTurn = _currentUserTranscript.isEmpty;
      _currentUserTranscript += text;

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
      _responseSilenceTimer?.cancel();
      _vadSilenceTimer?.cancel();
      _userSpokeInCurrentTurn = false;
      _flushUserTranscript();
      _resetWatchdog();
      _turnCompleteReceived = false;
      if (state.status != TutorState.speaking) {
        state = state.copyWith(status: TutorState.speaking);
      }
      _resetStuckTimer();
    };

    // Konec promluvy tutora (turn complete)
    client.onTurnComplete = () {
      _resetWatchdog();
      _responseSilenceTimer?.cancel();
      _vadSilenceTimer?.cancel();
      _userSpokeInCurrentTurn = false;
      HapticFeedback.selectionClick();
      final isStillPlaying = _audio.isPlaying;
      L.i('Gemini hlásí TurnComplete. (Hraje reprák? $isStillPlaying)');
      
      if (state.currentTranscript.isNotEmpty) {
        final tutorText = state.currentTranscript;
        L.i('Tutor řekl: "$tutorText"');
        
        // --- DETEKCE STAGNACE (Opakování slovníku) ---
        // 1. Intra-turn repetition (odstranění zacyklení uvnitř stejné promluvy)
        String finalTutorText = _removeIntraTurnRepetition(tutorText);
        
        // 2. Inter-turn repetition (opakování napříč tahy)
        bool isStagnating = false;
        if (_tutorTextHistory.isNotEmpty) {
           final currentWords = finalTutorText.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
           
           if (currentWords.isNotEmpty) {
             for (final historyText in _tutorTextHistory) {
               final historyWords = historyText.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
               if (historyWords.isNotEmpty) {
                 final intersection = currentWords.intersection(historyWords).length;
                 final union = currentWords.union(historyWords).length;
                 final similarity = intersection / union;
                 
                 // Zkontrolujeme také, zda nedošlo k přesnému zkopírování delší fráze (např. víc než 20 znaků)
                 final hasExactMatch = finalTutorText.length > 20 && historyText.toLowerCase().contains(finalTutorText.toLowerCase().substring(0, 20));
                 
                 if (similarity > 0.45 || hasExactMatch) {
                   isStagnating = true;
                   L.w('Detekována stagnace (Tutor se opakuje s podobností ${ (similarity * 100).toInt() }%). Vynucuji změnu tématu.');
                   break;
                 }
               }
             }
           }
        }
        
        if (isStagnating) {
           forceTopicChange();
           _tutorTextHistory.clear(); // Zabrání okamžitému dalšímu spuštění
        } else {
           _tutorTextHistory.add(finalTutorText);
           if (_tutorTextHistory.length > 3) {
             _tutorTextHistory.removeAt(0); // Uchováme jen poslední 3 promluvy
           }
        }
        
        final newMessages = List<ChatMessage>.from(state.messages)
          ..add(ChatMessage(finalTutorText, isUser: false));
        
        state = state.copyWith(
          currentTranscript: '',
          messages: newMessages,
          status: isStillPlaying ? TutorState.speaking : TutorState.listening,
        );

        // Pokud reprák ještě hraje, počkáme, až dozní v audio handleru; jinak jsme rovnou listening
        _turnCompleteReceived = isStillPlaying;

        // Uložení finálního přepisu řeči tutora do DB
        if (_currentSessionId != null) {
          repo.addTranscript(
            sessionId: _currentSessionId!,
            speaker: 'tutor',
            content: tutorText,
          );
        }
      } else {
        state = state.copyWith(
          status: isStillPlaying ? TutorState.speaking : TutorState.listening,
        );
        _turnCompleteReceived = isStillPlaying;
      }

      // Proaktivní obnova WebSocket relace při příliš vysoké spotřebě tokenů
      if (client.currentTokenCount > 25000) {
        L.w('Spotřeba tokenů (${client.currentTokenCount}) dosáhla limitu. Proaktivně provádím plynulý reconnect pro zamezení lagů...');
        client.forceReconnect();
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
      
      // Uložíme rozpracovaný transkript tutora (i neúplný), aby se neztratil z historie
      if (state.currentTranscript.isNotEmpty) {
        final partialText = state.currentTranscript;
        final newMessages = List<ChatMessage>.from(state.messages)
          ..add(ChatMessage(partialText, isUser: false));
        state = state.copyWith(
          status: TutorState.listening,
          currentTranscript: '',
          messages: newMessages,
        );
        // Uložení neúplné repliky do DB
        if (_currentSessionId != null) {
          repo.addTranscript(
            sessionId: _currentSessionId!,
            speaker: 'tutor',
            content: partialText,
          );
        }
      } else {
        state = state.copyWith(
          status: TutorState.listening,
          currentTranscript: '',
        );
      }
    };

    // Změna stavu připojení na síťové vrstvě
    client.onConnectionStatusChanged = (isConnected) {
      if (!isConnected && !_isStopping) {
        if (state.status == TutorState.listening || state.status == TutorState.speaking || state.status == TutorState.thinking) {
          // Výpadek uprostřed aktivního hovoru → reconnecting
          L.w('Spojení ztraceno během hovoru, přepínám na reconnecting...');
          state = state.copyWith(status: TutorState.reconnecting);
        } else if (state.status == TutorState.connecting) {
          // Výpadek při inicializaci (např. 1007 od preview API) → zůstáváme v connecting
          L.w('Spojení uzavřeno při inicializaci. Auto-reconnect probíhá, zůstávám v connecting...');
        }
      } else if (isConnected && (state.status == TutorState.reconnecting || state.status == TutorState.connecting)) {
        final wasReconnecting = state.status == TutorState.reconnecting;
        L.i('Spojení obnoveno, vracím se do stavu listening.');
        state = state.copyWith(status: TutorState.listening);
        _resetWatchdog();

        // Pokud došlo k reconnectu během běžícího hovoru, obnovíme kontext do nové WebSocket relace
        if (wasReconnecting && state.messages.isNotEmpty) {
          _restoreConversationContext(client);
        }
      }
    };

    // Příjem chybové zprávy z WebSocketu
    client.onError = (error) {
      state = state.copyWith(status: TutorState.error, errorMessage: error);
    };
  }

  /// Po výpadku a znovupřipojení WebSocketu injektuje do nové relace Gemini
  /// stručný souhrn dosavadní konverzace, aby model neztratil nit a plynule navázal.
  void _restoreConversationContext(GeminiLiveClient client) {
    try {
      final recentMessages = state.messages.length > 4 
          ? state.messages.sublist(state.messages.length - 4) 
          : state.messages;
      
      final historySummary = recentMessages.map((m) => '${m.isUser ? "Student" : "Tutor"}: ${m.text}').join('\n');
      
      L.i('Obnovuji kontext konverzace po reconnectu (${recentMessages.length} zpráv)...');
      client.sendClientContent(
        role: 'user',
        text: '[SYSTEM CONTEXT RECOVERY - RECONNECTED] '
              'We just reconnected. Here is the recent conversation context:\n$historySummary\n'
              'Continue seamlessly as AJ Tudor from where we left off. Listen to the student.',
        turnComplete: false,
      );
    } catch (e) {
      L.w('Chyba při obnově kontextu po reconnectu: $e');
    }
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
      _thinkingTimer?.cancel();
      _responseSilenceTimer?.cancel();
      _vadSilenceTimer?.cancel();
      _userSpokeInCurrentTurn = false;
      
      _wakelock.disable(); // Povolíme opětovné zhasínání displeje

      // Zastavení mikrofonu
      try {
        await _audio.stop();
      } catch (e, stack) {
        L.e('Chyba při zastavování audia', e, stack);
      }
      
      // Odpojení WebSocket klienta a odregistrování všech callbacků,
      // aby žádný zpožděný stream event (onDone, onError) nemohl měnit stav po konci session.
      if (ref.mounted) {
        try {
          final liveClient = ref.read(geminiLiveClientProvider);
          if (liveClient != null) {
            liveClient.disconnect();
            // Nullujeme callbacky — po disconnect() nás jejich případné zpožděné spuštění nezajímá
            liveClient.onTextReceived = null;
            liveClient.onUserTranscriptReceived = null;
            liveClient.onAudioReceived = null;
            liveClient.onTurnComplete = null;
            liveClient.onError = null;
            liveClient.onConnectionStatusChanged = null;
            liveClient.onToolCall = null;
            liveClient.onInterrupted = null;
            liveClient.onTokenCountUpdate = null;
          }
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
        if (ref.mounted && state.currentTranscript.isNotEmpty) {
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
    _thinkingTimer?.cancel();
    _responseSilenceTimer?.cancel();
    _vadSilenceTimer?.cancel();
    _userSpokeInCurrentTurn = false;
    
    // Zastavíme mikrofon, ale necháme WebSocket otevřený
    try {
      await _audio.stop();
    } catch (e) {
      L.w('Chyba při pozastavení mikrofonu: $e');
    }
    
    state = state.copyWith(status: TutorState.paused);
  }

  Future<void> resumeSession() async {
    if (state.status != TutorState.paused) return;
    
    L.i('Obnovuji konverzaci...');
    HapticFeedback.mediumImpact();
    
    final client = ref.read(geminiLiveClientProvider);
    if (client == null) {
      state = state.copyWith(status: TutorState.error, errorMessage: 'Chybí klient pro obnovení.');
      return;
    }
    
    // Znovu aktivujeme mikrofon bez ohledu na stav sítě,
    // aby mohl běžet na pozadí, jakmile se spojení obnoví.
    try {
      await _audio.start(onAudioChunk: (data) {
        _handleIncomingAudioChunk(data, client);
      });
    } catch (e) {
      L.e('Chyba mikrofonu při obnovení: $e');
      state = state.copyWith(status: TutorState.error, errorMessage: 'Chyba mikrofonu: $e');
      return;
    }
    
    if (!client.isConnected) {
      L.w('WebSocket je aktuálně odpojen, přecházím do stavu reconnecting a spouštím reconnect...');
      state = state.copyWith(status: TutorState.reconnecting);
      client.forceReconnect();
    } else {
      state = state.copyWith(status: TutorState.listening);
    }
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
      _resetThinkingTimer();
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

  /// Dynamická injekce instrukcí v reálném čase.
  ///
  /// Slouží k vynucenému řízení témat a prevenci repetice uprostřed běžícího hovoru
  /// přes strukturu BidiGenerateContentClientContent protokolu WebSocket.
  /// Instrukce se odesílá s `turnComplete: false`, takže model ji absorbuje
  /// bez spuštění halucinované odpovědi.
  void injectMidSessionGuidance(String hiddenInstruction) {
    final client = ref.read(geminiLiveClientProvider);
    
    if (client != null && client.isConnected && state.status != TutorState.idle) {
      L.i('Injektuji systémový mid-session update pro modifikaci pozornosti modelu.');
      
      // Posíláme jako 'user' s prefixem, protože Gemini Live API
      // nepodporuje roli 'system' v clientContent po úvodním setupu.
      client.sendClientContent(
        role: 'user',
        text: '[SYSTEM INSTRUCTION - NOT FROM STUDENT] $hiddenInstruction',
        turnComplete: false, 
      );
    }
  }

  /// Odstraní zjevné zacyklení modelu uvnitř jedné promluvy (když zopakuje stejnou větu/část).
  String _removeIntraTurnRepetition(String text) {
    if (text.isEmpty) return text;
    
    // Nejprve zkusíme rozdělit na věty
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final uniqueSentences = <String>[];
    
    for (final s in sentences) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) continue;
      
      bool isDuplicate = false;
      for (final existing in uniqueSentences) {
        final existingLower = existing.toLowerCase();
        final trimmedLower = trimmed.toLowerCase();
        
        // Přesná shoda
        if (existingLower == trimmedLower) {
          isDuplicate = true;
          break;
        }
        
        // Podřetězec (např. uťatá verze téže věty), pokud má alespoň 10 znaků
        if (trimmedLower.length > 10 && existingLower.contains(trimmedLower)) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        uniqueSentences.add(trimmed);
      } else {
        L.w('Odstraněno zacyklení uvnitř věty: "$trimmed"');
      }
    }
    
    return uniqueSentences.join(' ');
  }

  /// Vynucená změna tématu konverzace.
  ///
  /// Volá se uživatelským tlačítkem "Změnit téma" nebo heuristikou
  /// detekující nadměrnou sémantickou podobnost posledních tahů.
  void forceTopicChange() {
    HapticFeedback.lightImpact();
    injectMidSessionGuidance(
      "CRITICAL INSTRUCTION: Okamžitě opusti současné téma hovoru, "
      "protože se konverzace zacyklila. Přestaň klást otázky k dosavadnímu okruhu "
      "a plynule přejdi na absolutně novou oblast zájmů studenta. Použij přirozený "
      "oslí můstek. Neupozorňuj nahlas, že měníš téma na příkaz systému."
    );
  }

  /// Resetuje watchdog časovač aktivity.
  /// 
  /// Pokud 35 sekund nedojde k žádné komunikaci (uživatel ani AI neposílají zprávy/audio),
  /// watchdog usoudí, že došlo k tichému rozpadu socketu a vyvolá bezpečný reconnect.
  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 35), () {
      if (state.status != TutorState.idle && 
          state.status != TutorState.error && 
          state.status != TutorState.paused &&
          state.status != TutorState.reconnecting &&
          state.status != TutorState.connecting) {
        L.w('Watchdog: Žádná aktivita 35s, zkouším reconnect...');
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

  /// Zpracuje příchozí audio chunk z mikrofonu, řídí Mute Window a lokální VAD.
  void _handleIncomingAudioChunk(List<int> data, GeminiLiveClient client) {
    if (state.status == TutorState.listening) {
      if (_audio.isPlaying) {
        if (!_muteLogged) {
          L.w('🔇 MUTE WINDOW: Zahazuji zvuk z mikrofonu (reproduktor ještě hraje)');
          _muteLogged = true;
        }
      } else {
        if (_muteLogged) {
          L.i('🎤 MUTE WINDOW KONČÍ: Mikrofon je opět aktivní.');
          _muteLogged = false;
        }
        client.sendAudioChunk(data);
        _processAudioChunkForVAD(data, client);
      }
    } else if (state.status == TutorState.speaking) {
      if (_turnCompleteReceived && !_audio.isPlaying) {
        state = state.copyWith(status: TutorState.listening);
        _turnCompleteReceived = false;
        _userSpokeInCurrentTurn = false;
        L.i('🎤 Zvuk dozrál, přepínám stav z speaking na listening.');
      }
    }
  }

  /// Lokální detekce hlasové aktivity (VAD) z PCM 16-bit audio proudu.
  /// 
  /// Pokud uživatel promluví (i jednoslovně) a po 1.6s nastane ticho, popostrčí model (turnComplete: true),
  /// čímž se zamezí zasekávání modelu při čekání na další slova.
  void _processAudioChunkForVAD(List<int> buffer, GeminiLiveClient client) {
    if (buffer.length < 2) return;
    
    double sum = 0;
    final int sampleCount = buffer.length ~/ 2;
    final byteData = ByteData.sublistView(Uint8List.fromList(buffer));
    
    for (int i = 0; i < buffer.length - 1; i += 2) {
      final int sample = byteData.getInt16(i, Endian.little);
      sum += sample * sample;
    }
    
    final double rms = math.sqrt(sum / sampleCount);
    final double volume = math.sqrt(rms / 32768.0);
    
    const double voiceThreshold = 0.045;
    
    if (volume >= voiceThreshold) {
      if (!_userSpokeInCurrentTurn) {
        _userSpokeInCurrentTurn = true;
        L.d('🎙️ VAD: Detekována řeč studenta (vol: ${volume.toStringAsFixed(3)})');
      }
      _vadSilenceTimer?.cancel();
    } else if (_userSpokeInCurrentTurn) {
      if (_vadSilenceTimer == null || !_vadSilenceTimer!.isActive) {
        _vadSilenceTimer = Timer(const Duration(milliseconds: 1600), () {
          if (state.status == TutorState.listening && _userSpokeInCurrentTurn) {
            L.i('🎙️ VAD: Detekován konec řeči studenta (1.6s ticho po domluvení). Popostrkuji model...');
            _userSpokeInCurrentTurn = false;
            client.nudgeModel();
            _resetThinkingTimer();
          }
        });
      }
    }
  }

  /// Spustí hlídání reakce modelu po domluvě studenta.
  /// 
  /// Pokud uživatel domluví a Gemini do 1.8s neodpoví,
  /// model popostrčíme přes nudgeModel(). Pokud ani po dalších 5s neodpoví,
  /// vyvoláme čistý reconnect s obnovením kontextu.
  void _resetResponseSilenceTimer() {
    _responseSilenceTimer?.cancel();
    _responseSilenceTimer = Timer(const Duration(milliseconds: 1800), () {
      if (state.status == TutorState.listening) {
        L.i('Detekováno ticho po přepisu řeči studenta (1.8s bez odpovědi AI). Popostrkuji model...');
        final client = ref.read(geminiLiveClientProvider);
        if (client != null && client.isConnected) {
          _userSpokeInCurrentTurn = false;
          client.nudgeModel();
          
          // Druhý záchranný krok po dalších 5 sekundách:
          _responseSilenceTimer = Timer(const Duration(seconds: 5), () {
            if (state.status == TutorState.listening) {
              L.w('Model nereaguje ani po popostrčení (6.8s bez odpovědi). Vyvolávám forceReconnect...');
              state = state.copyWith(status: TutorState.reconnecting);
              client.forceReconnect();
            }
          });
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
          if (_audio.isPlaying) {
             L.i('Stuck timer: Audio ještě hraje, odkládám reset o dalších 10s.');
             _resetStuckTimer();
          } else {
             L.w('Detekováno zaseknutí ve stavu speaking (10s ticho), vracím do listening.');
             state = state.copyWith(status: TutorState.listening);
          }
        }
      });
    }
  }

  /// Resetuje thinking timer.
  ///
  /// Pokud tutor zůstane ve stavu `thinking` déle než 15 sekund bez jakékoliv
  /// odpovědi (ani audio, ani text), přepne se zpět do `listening`.
  void _resetThinkingTimer() {
    _thinkingTimer?.cancel();
    if (state.status == TutorState.thinking) {
      _thinkingTimer = Timer(const Duration(seconds: 15), () {
        if (state.status == TutorState.thinking) {
          L.w('Thinking timeout (15s bez odpovědi), vracím do listening.');
          state = state.copyWith(status: TutorState.listening);
        }
      });
    }
  }
}

/// Poskytuje globální instanci [VoiceTutorAgent] a její stav pro UI.
final voiceTutorAgentProvider = NotifierProvider<VoiceTutorAgent, VoiceTutorState>(VoiceTutorAgent.new);
