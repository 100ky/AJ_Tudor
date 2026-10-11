import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gemini/gemini_providers.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/scenario_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/models/chat_message.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../prompt/live_tutor_prompts.dart';
import '../prompt/system_prompt_builder.dart';
import '../audio/audio_session_controller.dart';
import '../system/wakelock_service.dart';
import '../gemini/gemini_live_client.dart';
import '../gemini/speech_transcription_service.dart';

import 'memory_manager_agent.dart';
import 'voice_director_agent.dart';
import 'voice_tutor/pre_roll_buffer.dart';
import 'voice_tutor/session_metrics.dart';
import 'voice_tutor/speech_activity_detector.dart';
import 'voice_tutor/student_utterance.dart';
import 'voice_tutor/tutor_text_analysis.dart';
import 'voice_tutor/tutor_timers.dart';


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
    bool clearScenario = false,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedScenarioId: clearScenario ? null : (selectedScenarioId ?? this.selectedScenarioId),
      scenarioContext: clearScenario ? null : (scenarioContext ?? this.scenarioContext),
    );
  }
}

/// Státový agent (Notifier) řídící kompletní hlasovou konverzaci s tutorem.
///
/// Integruje WebSocket klienta, mikrofonní audio vstup, audio playback,
/// správu stavu aplikace (např. uspání displeje, přechod na pozadí)
/// a asynchronní spouštění vyhodnocení lekce po jejím skončení.
class VoiceTutorAgent extends Notifier<VoiceTutorState> with WidgetsBindingObserver {
  final TutorTimers _timers = TutorTimers();
  final SpeechActivityDetector _vad = SpeechActivityDetector();
  int? _currentSessionId;
  bool _isStopping = false;
  bool _isStarting = false;
  bool _isObserverRegistered = false;

  // Probíhající ukončování lekce; start na něj počká, jinak by mu stop vynuloval ID nové lekce.
  Future<void>? _pendingStop;

  // Zvyšuje se s každým ukončením. Start podle ní pozná, že byl během čekání zrušen,
  // a nespustí hovor, ke kterému už neexistuje lekce v databázi (přepis by se neukládal).
  int _sessionGeneration = 0;

  // Průběžný nashromážděný přepis řeči uživatele pro aktuální repliku.
  String _currentUserTranscript = '';

  // Heuristiky pro detekci frustrace a stagnace
  int _consecutiveShortAnswers = 0;
  final List<String> _tutorTextHistory = [];
  bool _turnCompleteReceived = false;
  bool _muteLogged = false;
  bool _userSpokeInCurrentTurn = false;

  // Ruční detekce řeči: začátek a konec řeči studenta serveru ohlašuje aplikace.
  // Zvuk se posílá jen mezi activityStart a activityEnd, úvod před zjištěnou řečí
  // drží PreRollBuffer.
  bool _activityOpen = false;
  final PreRollBuffer _preRoll = PreRollBuffer();

  // Repliky studenta: zvuk pro opravný přepis a čekání na uložení do DB.
  StudentUtterance? _utterance; // právě nahrávaná (mezi activityStart a activityEnd)
  StudentUtterance? _lastUtterance; // poslední ukončená, k ní patří živý přepis
  final List<StudentUtterance> _pendingUtterances = [];

  // Skryté pokyny (rada režiséra, odlehčení, tichá změna tématu) čekající na konec tahu tutora.
  // Zpráva clientContent podle dokumentace Live API přeruší právě generovanou odpověď,
  // proto je posíláme až po turnComplete: model nemluví a mikrofon je ještě ztlumený.
  final List<String> _pendingGuidance = [];

  // ─── SESSION METRIKY pro terminálový výstup ───
  final SessionMetrics _metrics = SessionMetrics();

  late final WakelockService _wakelock;
  late final AudioSessionController _audio;
  late final SessionRepository _repo;
  late final ProfileRepository _profileRepo;
  late final ScenarioRepository _scenarioRepo;
  late final MemoryManagerAgent _memory;
  late final VoiceDirectorAgent _director;
  late final SpeechTranscriptionService _transcriber;

  String _targetLevelSnapshot = 'B1';
  String? _userFactsSnapshot;
  String? _recentTopicsSnapshot;

  @override
  VoiceTutorState build() {
    // Inicializace závislých služeb přes Riverpod
    _wakelock = ref.read(wakelockServiceProvider);
    _audio = ref.read(audioSessionControllerProvider);
    _repo = ref.read(sessionRepositoryProvider);
    _profileRepo = ref.read(profileRepositoryProvider);
    _scenarioRepo = ref.read(scenarioRepositoryProvider);
    _memory = ref.read(memoryManagerAgentProvider);
    _director = ref.read(voiceDirectorAgentProvider.notifier);
    _transcriber = ref.read(speechTranscriptionServiceProvider);


    // Registrace do životního cyklu aplikace (pro detekci pozadí/popředí)
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }

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
      if (_isObserverRegistered) {
        WidgetsBinding.instance.removeObserver(this);
        _isObserverRegistered = false;
      }

      // Zrušení všech běžících časovačů
      _timers.cancelAll();

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
      state = state.copyWith(clearScenario: true);
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
    if (_isStarting) {
      L.i('startSession ignorováno - již probíhá spouštění.');
      return;
    }
    _isStarting = true;

    final pendingStop = _pendingStop;
    if (pendingStop != null) {
      L.i('startSession čeká na dokončení ukončování předchozí session...');
      await pendingStop;
    }

    if (_currentSessionId != null) {
      L.w('Pokus o startSession, ale předchozí session ($_currentSessionId) nebyla uzavřena. Uzavírám a odesílám k analýze.');
      await stopSession('forced_restart');
    }

    final generation = _sessionGeneration;

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
      _isStarting = false;
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
      final newSessionId = sessionResult.getOrThrow();
      if (_isStartCancelled(generation)) {
        // Stop proběhl dřív, než lekce v DB vznikla, takže ji neuzavřel – uzavřeme ji sami.
        await _repo.closeSession(newSessionId);
        return;
      }
      _currentSessionId = newSessionId;
      _currentUserTranscript = '';
      // Vlastní log lekce: k problému nahlášenému v historii se dá dohledat i po restartech
      await L.startSessionLog(newSessionId);

      // Reset session metrik
      _metrics.start();
      _userSpokeInCurrentTurn = false;
      _vad.reset();
      _resetSpeechActivity();

      // Pokud máme vybraný scénář, označíme ho jako použitý v databázi
      if (state.selectedScenarioId != null && state.selectedScenarioId! > 0) {
        await _scenarioRepo.markScenarioUsed(state.selectedScenarioId!);
      }

      // Resetujeme stav režiséra na pozadí pro novou lekci
      _director.reset();

      // 1. Příprava dat a promptu pro AI – načtení KOMPLETNÍHO profilu studenta
      final userProfile = await _profileRepo.getUserProfile();
      final targetLevel = userProfile?.targetLevel ?? 'B1';
      _targetLevelSnapshot = targetLevel;
      _userFactsSnapshot = userProfile?.userFacts;
      _recentTopicsSnapshot = userProfile?.topicPreferences;
      // Stop během čekání na DB už lekci uzavřel – hovor bez lekce by se neuložil ani nevyhodnotil
      if (_isStartCancelled(generation)) return;
      final voice = ref.read(voiceProvider);
      final isImmersive = ref.read(immersiveModeProvider);


      // Získáme náhodný osobní fakt pro zamezení opakování úvodu
      final personalFact = SystemPromptBuilder.getRandomPersonalFact();

      // Sestavení dynamického promptu s kompletním kontextem z profilu
      final systemPrompt = SystemPromptBuilder.buildTutorPrompt(
        scenarioContext: state.scenarioContext == '__free_talk__'
            ? null
            : state.scenarioContext,
        targetLevel: targetLevel,
        isImmersive: isImmersive,
        recurringErrors: userProfile?.recurringErrors,
        vocabulary: userProfile?.vocabulary,
        recentTopics: userProfile?.topicPreferences,
        memoryBriefing: userProfile?.memoryBriefing,
        userFacts: userProfile?.userFacts,
        personalFact: personalFact,
      );

      // ─── STRUKTUROVANÉ LOGOVÁNÍ STARTU SESSION ───
      final scenarioLabel = state.scenarioContext == '__free_talk__'
          ? 'Volná konverzace (Free Talk)'
          : state.scenarioContext != null
              ? 'Role-play scénář'
              : 'Volná konverzace';

      L.sessionStart(
        _currentSessionId!,
        scenario: scenarioLabel,
        level: targetLevel,
        immersive: isImmersive,
      );

      // Log profilu studenta
      final profileLines = StringBuffer();
      profileLines.writeln('Úroveň: $targetLevel');
      if (userProfile?.userFacts != null && userProfile!.userFacts.isNotEmpty && userProfile.userFacts != '[]') {
        profileLines.writeln('Fakta o studentovi: ${L.truncate(userProfile.userFacts, 200)}');
      } else {
        profileLines.writeln('Fakta o studentovi: (zatím žádná)');
      }
      if (userProfile?.recurringErrors != null && userProfile!.recurringErrors.isNotEmpty && userProfile.recurringErrors != '[]') {
        profileLines.writeln('Opakující se chyby: ${L.truncate(userProfile.recurringErrors, 200)}');
      }
      if (userProfile?.vocabulary != null && userProfile!.vocabulary.isNotEmpty && userProfile.vocabulary != '[]') {
        profileLines.writeln('Slovní zásoba: ${L.truncate(userProfile.vocabulary, 150)}');
      }
      if (userProfile?.memoryBriefing != null && userProfile!.memoryBriefing!.isNotEmpty) {
        profileLines.writeln('Briefing z minulé lekce: ${L.truncate(userProfile.memoryBriefing!, 200)}');
      }
      L.block('PROFILE', 'Profil studenta', profileLines.toString());

      // Log parametrů promptu
      final promptLines = StringBuffer();
      promptLines.writeln('scenarioContext: ${state.scenarioContext == '__free_talk__' ? 'null (free talk)' : state.scenarioContext != null ? L.truncate(state.scenarioContext!, 100) : 'null'}');
      promptLines.writeln('targetLevel: $targetLevel');
      promptLines.writeln('isImmersive: $isImmersive');
      promptLines.writeln('personalFact: ${L.truncate(personalFact, 80)}');
      promptLines.writeln('voice: $voice');
      promptLines.writeln('Délka promptu: ${systemPrompt.length} znaků');
      L.block('PROMPT', 'Parametry systémového promptu', promptLines.toString());

      const liveModelName = 'models/${GeminiModels.defaultLiveModel}';

      // Spuštění WebSocket připojení (konec řeči studenta určuje místní detekce řeči)
      client.muteOutput = false;
      client.connect(
        modelName: liveModelName,
        systemPrompt: systemPrompt,
        voiceName: voice,
      );

      // Zaregistrování callbacků pro zpracování zpráv z klienta
      _setupClientCallbacks(client);

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

      if (_isStartCancelled(generation)) {
        // Stop mohl vypnout mikrofon dřív, než se stihl zapnout
        await _audio.stop();
        return;
      }

      state = state.copyWith(status: TutorState.listening, currentTranscript: '');
      _resetWatchdog();

      // Aktivně spustíme konverzaci ze strany AI zasláním skrytého inicializačního textu
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!ref.mounted) return;
        final currentClient = ref.read(geminiLiveClientProvider);
        // Když student mezitím začal mluvit sám, úvod tutora vynecháme – odpoví jemu
        if (currentClient != null &&
            currentClient.isConnected &&
            state.status == TutorState.listening &&
            !_activityOpen) {
          state = state.copyWith(status: TutorState.thinking);
          _resetThinkingTimer();

          final prepTopicJson = userProfile?.preparedTopic;
          String? preparedOpener;
          if (prepTopicJson != null && prepTopicJson.isNotEmpty) {
            try {
              final data = jsonDecode(prepTopicJson);
              preparedOpener = data['openerEn']?.toString();
            } catch (_) {}
          }

          currentClient.sendText(LiveTutorPrompts.opening(
            scenarioContext: state.scenarioContext,
            preparedOpener: preparedOpener,
            briefing: userProfile?.memoryBriefing,
          ));
        }
      });


    } catch (e, stack) {
      L.e('Chyba startu session', e, stack);
      state = state.copyWith(status: TutorState.error, errorMessage: 'Neočekávaná chyba při startu: $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Zda byla lekce během spouštění ukončena (nebo agent zanikl).
  bool _isStartCancelled(int generation) {
    if (generation == _sessionGeneration && ref.mounted) return false;
    L.w('Spouštění session bylo přerušeno jejím ukončením – hovor nespouštím.');
    return true;
  }

  /// Uloží repliku do přepisu aktuální lekce v databázi (pokud lekce běží).
  void _saveTranscript(String speaker, String content) {
    final sessionId = _currentSessionId;
    if (sessionId == null) {
      L.w('Replika ($speaker) se neuložila – neběží žádná session v DB.');
      return;
    }
    _repo.addTranscript(sessionId: sessionId, speaker: speaker, content: content);
  }

  /// Uloží rozpracovanou (i neúplnou) repliku tutora do historie a databáze,
  /// aby se neztratila, a vyprázdní živý přepis.
  ///
  /// S [status] zároveň přepne stav tutora (i když žádný rozpracovaný text není).
  void _commitPartialTutorTranscript({TutorState? status}) {
    final partial = state.currentTranscript;
    if (!hasSpokenWords(partial)) {
      if (status != null || partial.isNotEmpty) {
        state = state.copyWith(status: status, currentTranscript: '');
      }
      return;
    }
    state = state.copyWith(
      status: status,
      currentTranscript: '',
      messages: [...state.messages, ChatMessage(partial, isUser: false)],
    );
    _saveTranscript('tutor', partial);
  }

  /// Uzavře živý přepis poslední repliky studenta (tutor začal odpovídat): spočítá metriky
  /// a frustraci a předá repliku k uložení – uloží se, až doběhne i opravný přepis.
  void _flushUserTranscript() {
    final utterance = _lastUtterance;
    if (utterance != null && !utterance.liveDone) {
      utterance.liveDone = true;
      utterance.insertIndex ??= state.messages.length;
      _showUtteranceText(utterance);
      _trySaveUtterance(utterance);
    }

    if (_currentUserTranscript.trim().isNotEmpty) {
      final userText = _currentUserTranscript.trim();
      _currentUserTranscript = '';

      // --- DETEKCE FRUSTRACE (Krátké odpovědi) ---
      // Ignorujeme běžná výplňková slova a váhání studenta při přemýšlení (uh, em, um apod.)
      final wordCount = meaningfulWordCount(userText);

      if (wordCount != null) {
        // ─── METRIKA: délka odpovědi uživatele ───
        _metrics.recordUserAnswer(wordCount);

        if (wordCount <= 3) {
          _consecutiveShortAnswers++;
          if (_consecutiveShortAnswers >= 3) {
             _metrics.frustrationDetections++;
             L.w('Detekována frustrace/nezájem (3x krátká odpověď za sebou). Injektuji afektivní rekalibraci.');
             injectMidSessionGuidance(LiveTutorPrompts.frustrationRecalibration);
             _consecutiveShortAnswers = 0; // reset po injekci
          }
        } else {
          _consecutiveShortAnswers = 0;
        }
      }

      // ─── METRIKA: timestamp konce řeči studenta (pro měření reakční doby AI) ───
      _metrics.markUserSpeechEnd();

      // Bez nahrané repliky se ukládá rovnou živý přepis
      if (utterance == null && _currentSessionId != null) {
        L.i('💾 [TRANSCRIPT] Ukládám transkript uživatele do DB: "$userText"');
        _saveTranscript('user', userText);
      }
    }
  }

  /// Ohlásí serveru začátek řeči studenta a pošle úvod zachycený před zjištěnou řečí.
  void _openActivity(GeminiLiveClient client) {
    if (_activityOpen || !client.sendActivityStart()) return;
    _activityOpen = true;

    final previous = _lastUtterance;
    final sessionId = _currentSessionId;
    if (previous != null && !previous.liveDone && !previous.saved) {
      // Tutor ještě neodpověděl: pokračování patří do stejného tahu i stejné repliky
      previous.reopen();
      _utterance = previous;
    } else if (sessionId != null) {
      final utterance = StudentUtterance(sessionId: sessionId)..previousTutorLine = _lastTutorLine();
      _pendingUtterances.add(utterance);
      _utterance = utterance;
    }

    for (final chunk in _preRoll.drain()) {
      client.sendAudioChunk(chunk);
      _utterance?.addAudio(chunk);
    }
  }

  /// Ohlásí konec řeči studenta (model začne odpovídat) a pošle repliku k opravnému přepisu.
  ///
  /// Bez [client] se serveru nic neposílá (spojení spadlo nebo lekce končí).
  void _closeActivity(GeminiLiveClient? client) {
    if (!_activityOpen) return;
    _activityOpen = false;
    client?.sendActivityEnd();

    final utterance = _utterance;
    _utterance = null;
    if (utterance == null) return;
    utterance.endedAt = DateTime.now();
    _lastUtterance = utterance;
    _startCorrection(utterance);
  }

  /// Přepíše zvuk repliky znovu (živý přepis občas zapíše řeč jiným jazykem)
  /// a výsledek ukáže v bublině a uloží.
  void _startCorrection(StudentUtterance utterance) {
    final round = utterance.beginCorrection();
    _correctedTranscript(utterance).then((text) {
      if (!utterance.isCurrentRound(round)) return;
      if (text == null) {
        L.w('Opravný přepis nedoběhl, platí živý přepis.');
      } else if (text.isEmpty) {
        L.i('✍️ Opravný přepis: v nahrávce není řeč.');
      }
      utterance.correctedText = text;
      utterance.correctionDone = true;
      _showUtteranceText(utterance);
      _trySaveUtterance(utterance);
    });
  }

  /// Opravný přepis zvuku repliky; null, když se nepodaří (pak platí živý přepis).
  Future<String?> _correctedTranscript(StudentUtterance utterance) async {
    final audio = utterance.audioBytes();
    if (audio.isEmpty) return null;
    try {
      return await _transcriber
          .transcribe(audio, previousTutorLine: utterance.previousTutorLine)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      L.w('Opravný přepis repliky selhal: $e');
      return null;
    }
  }

  /// Ukáže v bublině repliky nejlepší známý přepis. Když bublina ještě není
  /// (živý přepis nepřišel vůbec), vloží ji před odpověď tutora.
  void _showUtteranceText(StudentUtterance utterance) {
    if (!ref.mounted) return;
    final text = utterance.finalText;
    final messages = List<ChatMessage>.from(state.messages);
    final message = utterance.message;
    final index = message == null ? -1 : messages.indexWhere((m) => identical(m, message));

    if (text.isEmpty) {
      // Opravný přepis v nahrávce neslyšel řeč: bublina s výmyslem živého přepisu zmizí
      if (index >= 0 && utterance.correctionDone) {
        messages.removeAt(index);
        utterance.message = null;
        state = state.copyWith(messages: messages);
      }
      return;
    }

    if (index >= 0) {
      if (messages[index].text == text) return;
      messages[index] = ChatMessage(text, isUser: true);
      utterance.message = messages[index];
    } else {
      // Dokud může přijít živý přepis, bublinu vytvoří on
      if (!utterance.liveDone) return;
      final at = (utterance.insertIndex ?? messages.length).clamp(0, messages.length);
      final inserted = ChatMessage(text, isUser: true);
      messages.insert(at, inserted);
      utterance.message = inserted;
    }
    state = state.copyWith(messages: messages);
  }

  /// Uloží repliku studenta do DB, jakmile je znám živý i opravný přepis.
  void _trySaveUtterance(StudentUtterance utterance) {
    if (!utterance.readyToSave) return;
    utterance.saved = true;
    _pendingUtterances.remove(utterance);

    final text = utterance.finalText;
    if (text.isEmpty && utterance.liveText.trim().isNotEmpty) {
      L.i('Replika bez řeči (ruch), neukládám živý přepis "${utterance.liveText.trim()}".');
    }
    if (text.isNotEmpty) {
      if (text != utterance.liveText.trim()) {
        L.i('✍️ Opravný přepis repliky studenta: "${utterance.liveText.trim()}" → "$text"');
      }
      L.i('💾 [TRANSCRIPT] Ukládám repliku studenta do DB: "$text"');
      _repo.addTranscript(
        sessionId: utterance.sessionId,
        speaker: 'user',
        content: text,
        timestamp: utterance.endedAt,
      );
    }
    utterance.markSettled();
  }

  /// Poslední replika tutora (kontext pro opravný přepis).
  String? _lastTutorLine() {
    for (final message in state.messages.reversed) {
      if (!message.isUser) return message.text;
    }
    return null;
  }

  /// Výchozí stav ruční detekce řeči a replik studenta (nová lekce nebo konec lekce).
  void _resetSpeechActivity() {
    _activityOpen = false;
    _utterance = null;
    _lastUtterance = null;
    _pendingUtterances.clear();
    _preRoll.clear();
  }

  /// Zaregistruje všechny události příchozí z WebSocket klienta Gemini.
  void _setupClientCallbacks(GeminiLiveClient client) {
    client.onTextReceived = _onTextReceived;
    client.onUserTranscriptReceived = _onUserTranscriptReceived;
    client.onAudioReceived = _onAudioReceived;
    client.onTurnComplete = () => _onTurnComplete(client);
    client.onToolCall = _onToolCall;
    client.onInterrupted = _onInterrupted;
    client.onConnectionStatusChanged =
        (isConnected) => _onConnectionStatusChanged(isConnected, client);
    client.onError = _onError;
  }

  /// Příjem textové části odpovědi AI.
  void _onTextReceived(String text) {
    _timers.cancel(TutorTimer.thinking);
    _timers.cancel(TutorTimer.responseSilence);
    _flushUserTranscript();
    _resetWatchdog();
    _resetStuckTimer();
    L.i('Text z Gemini: $text');
    state = state.copyWith(
      status: _keepPaused(TutorState.speaking),
      // Postupně lepíme přicházející textové kousky k sobě
      currentTranscript: state.currentTranscript + text,
    );
  }

  /// Příjem dokončeného přepisu řeči uživatele (Speech-to-Text).
  void _onUserTranscriptReceived(String text) {
    if (text.trim().isEmpty) return;

    // Odfiltrování asijských znaků (např. korejské 응), které STT někdy halucinuje na tichý povzdech
    final cleanChunk = stripCjkCharacters(text);
    if (cleanChunk.trim().isEmpty) {
      L.vad('Ignoruji STT chunk obsahující pouze asijské znaky nebo prázdný: "$text"');
      return;
    }

    // Konec řeči určuje místní detekce řeči, přepis na časovače nesahá
    _resetWatchdog();

    HapticFeedback.lightImpact();
    L.i('STT chunk uživatele: "$cleanChunk"');

    final isNewTurn = _currentUserTranscript.isEmpty;
    _currentUserTranscript += cleanChunk;
    final liveText = _currentUserTranscript.trim();

    // Hotový opravný přepis má v bublině přednost před živým (a ruch bez řeči bublinu nemá)
    final utterance = _lastUtterance;
    if (utterance != null && !utterance.saved) utterance.liveText = liveText;
    final shown = utterance != null && utterance.correctionDone ? utterance.finalText : liveText;

    final newMessages = List<ChatMessage>.from(state.messages);
    final previous = utterance?.message;
    final index = previous == null ? -1 : newMessages.indexWhere((m) => identical(m, previous));
    ChatMessage? message;
    if (shown.isEmpty) {
      if (index >= 0) newMessages.removeAt(index);
    } else {
      message = ChatMessage(shown, isUser: true);
      if (index >= 0) {
        newMessages[index] = message;
      } else if (!isNewTurn && newMessages.isNotEmpty && newMessages.last.isUser) {
        // Rozpracovaná replika studenta se průběžně přepisuje v poslední bublině
        newMessages[newMessages.length - 1] = message;
      } else {
        newMessages.add(message);
      }
    }
    if (utterance != null && !utterance.saved) utterance.message = message;
    state = state.copyWith(messages: newMessages);

    if (utterance != null) _trySaveUtterance(utterance);
  }

  /// Detekce, že začala téct audio data z AI.
  void _onAudioReceived() {
    _timers.cancel(TutorTimer.thinking);
    _timers.cancel(TutorTimer.responseSilence);
    _timers.cancel(TutorTimer.playbackComplete);
    _resetSpeechDetectionUnlessSpeaking();
    _flushUserTranscript();
    _resetWatchdog();

    // ─── METRIKA: reakční doba AI (ms od konce řeči studenta do první audio odpovědi) ───
    _metrics.recordResponseStart();
    _turnCompleteReceived = false;
    if (state.status != TutorState.speaking && !_isPaused) {
      state = state.copyWith(status: TutorState.speaking);
    }
    _resetStuckTimer();
  }

  bool get _isPaused => state.status == TutorState.paused;

  /// Tutor mluví nebo domluvil: detekce řeči začne znovu. Rozpracovanou řeč studenta
  /// (např. skočil tutorovi do přemýšlení) to ale nesmí přerušit – po tichu se musí ukončit.
  void _resetSpeechDetectionUnlessSpeaking() {
    if (_activityOpen) return;
    _timers.cancel(TutorTimer.vadSilence);
    _userSpokeInCurrentTurn = false;
  }

  /// Události ze serveru (dokončený tah, přerušení) nesmí zrušit pauzu nastavenou studentem.
  TutorState _keepPaused(TutorState next) => _isPaused ? TutorState.paused : next;

  /// Konec promluvy tutora (turn complete).
  void _onTurnComplete(GeminiLiveClient client) {
    _resetWatchdog();
    _timers.cancel(TutorTimer.responseSilence);
    _resetSpeechDetectionUnlessSpeaking();
    HapticFeedback.selectionClick();
    final isStillPlaying = _audio.isPlaying;
    L.i('Gemini hlásí TurnComplete. (Hraje reprák? $isStillPlaying)');

    final nextStatus =
        _keepPaused(isStillPlaying ? TutorState.speaking : TutorState.listening);

    if (hasSpokenWords(state.currentTranscript)) {
      final tutorText = state.currentTranscript;
      L.i('Tutor řekl: "$tutorText"');

      // ─── METRIKA: délka odpovědi tutora ───
      _metrics.recordTutorAnswer(tutorText);
      // --- DETEKCE STAGNACE (Opakování slovníku) ---
      // 1. Intra-turn repetition (odstranění zacyklení uvnitř stejné promluvy)
      final finalTutorText = removeIntraTurnRepetition(tutorText);

      // 2. Inter-turn repetition (opakování napříč tahy)
      final similarity = repeatedTurnSimilarity(finalTutorText, _tutorTextHistory);

      if (similarity != null) {
         L.w('Detekována stagnace (Tutor se opakuje s podobností ${ (similarity * 100).toInt() }%). Vynucuji změnu tématu.');
         forceTopicChange(promptImmediateResponse: false);
         _tutorTextHistory.clear(); // Zabrání okamžitému dalšímu spuštění
      } else {
         _tutorTextHistory.add(finalTutorText);
         if (_tutorTextHistory.length > 3) {
           _tutorTextHistory.removeAt(0); // Uchováme jen poslední 3 promluvy
         }
      }

      state = state.copyWith(
        currentTranscript: '',
        messages: [...state.messages, ChatMessage(finalTutorText, isUser: false)],
        status: nextStatus,
      );

      // Uložení finálního přepisu řeči tutora do DB
      _saveTranscript('tutor', tutorText);
    } else {
      if (state.currentTranscript.isNotEmpty) {
        L.w('Tah tutora bez slov ("${state.currentTranscript}") – do přepisu ho neukládám.');
      }
      state = state.copyWith(currentTranscript: '', status: nextStatus);
    }

    // Model domluvil – teď můžeme bezpečně předat skryté pokyny, aniž bychom ho utnuli
    _flushPendingGuidance();

    // Pokud reprák ještě hraje, počkáme, až dozní v audio handleru nebo v časovači; jinak jsme rovnou listening
    _turnCompleteReceived = isStillPlaying;
    if (isStillPlaying) {
      _resetStuckTimer();
      _scheduleListeningAfterPlayback();
    }

    // Asynchronní analýza a režie hovoru na pozadí (VoiceDirectorAgent)
    if (_currentSessionId != null && state.messages.isNotEmpty) {
      _director.onTurnCompleted(
        sessionId: _currentSessionId!,
        messages: state.messages,
        targetLevel: _targetLevelSnapshot,
        userFacts: _userFactsSnapshot,
        recentTopics: _recentTopicsSnapshot,
        onWhisperReady: (whisper) {
          L.i('VoiceDirector: Našeptávám tutorovi: "$whisper"');
          injectMidSessionGuidance(LiveTutorPrompts.directorWhisper(whisper), turnComplete: false);
        },
      );
    }

    // Proaktivní obnova WebSocket relace při příliš vysoké spotřebě tokenů
    if (client.currentTokenCount > 25000) {
      L.w('Spotřeba tokenů (${client.currentTokenCount}) dosáhla limitu. Proaktivně provádím plynulý reconnect pro zamezení lagů...');
      client.forceReconnect();
    }
  }

  /// Po dohrání zbývajícího audia tutora přepne do poslechu.
  void _scheduleListeningAfterPlayback() {
    final waitMs = math.max(150, _audio.remainingPlaybackMs + 150);
    L.i('Naplánován přechod do listening za ${waitMs}ms po dohrání audia.');
    _timers.start(TutorTimer.playbackComplete, Duration(milliseconds: waitMs), () {
      if (state.status == TutorState.speaking) {
        state = state.copyWith(status: TutorState.listening);
        _turnCompleteReceived = false;
        _userSpokeInCurrentTurn = false;
        L.i('🎤 Zvuk dozrál (časovač doznění), přepínám stav z speaking na listening.');
      }
    });
  }

  /// Zpracování logování chyb přes Function Calling.
  void _onToolCall(String name, Map<String, dynamic> args) {
    if (name == 'log_error' && _currentSessionId != null) {
      _repo.addErrorLog(
        sessionId: _currentSessionId!,
        errorType: args['error_type'] ?? 'grammar',
        userSaid: args['user_said'] ?? '',
        correctForm: args['correct_form'] ?? '',
        explanation: args['explanation'] ?? '',
      );
      L.i('✅ Chyba zalogována v reálném čase přes Function Calling.');
    }
  }

  /// Zpracování přerušení mluvení modelu uživatelem.
  void _onInterrupted() {
    _resetWatchdog();
    _resetStuckTimer();
    _timers.cancel(TutorTimer.playbackComplete);
    _turnCompleteReceived = false;
    _director.dismissTip();
    L.i('Model byl přerušen uživatelem.');

    // Uložíme rozpracovaný transkript tutora (i neúplný), aby se neztratil z historie
    _commitPartialTutorTranscript(status: _keepPaused(TutorState.listening));
  }

  /// Změna stavu připojení na síťové vrstvě.
  void _onConnectionStatusChanged(bool isConnected, GeminiLiveClient client) {
    if (!isConnected && !_isStopping) {
      _dropActivityAfterDisconnect();
      if (state.status == TutorState.listening || state.status == TutorState.speaking || state.status == TutorState.thinking) {
        // Výpadek uprostřed aktivního hovoru → reconnecting
        _metrics.reconnects++;
        L.w('Spojení ztraceno během hovoru, přepínám na reconnecting... (reconnect #${_metrics.reconnects})');
        state = state.copyWith(status: TutorState.reconnecting);
      } else if (state.status == TutorState.connecting) {
        // Výpadek při inicializaci (např. 1007 od preview API) → zůstáváme v connecting
        L.w('Spojení uzavřeno při inicializaci. Auto-reconnect probíhá, zůstávám v connecting...');
      }
    } else if (isConnected && (state.status == TutorState.reconnecting || state.status == TutorState.connecting)) {
      final wasReconnecting = state.status == TutorState.reconnecting;
      // Nové spojení rozpracovanou řeč nezná (vynucený reconnect neohlásí výpadek)
      _dropActivityAfterDisconnect();
      L.i('Spojení obnoveno, vracím se do stavu listening.');
      state = state.copyWith(status: TutorState.listening);
      _resetWatchdog();

      // Pokud došlo k reconnectu během běžícího hovoru, obnovíme kontext do nové WebSocket relace
      if (wasReconnecting && state.messages.isNotEmpty) {
        _restoreConversationContext(client);
      }
    }
  }

  /// Se spojením zanikla i rozpracovaná řeč studenta na serveru. Replika se uloží
  /// z opravného přepisu (odpověď na ni už nepřijde) a další řeč začne novou.
  void _dropActivityAfterDisconnect() {
    _preRoll.clear();
    if (!_activityOpen) return;
    _closeActivity(null);
    final utterance = _lastUtterance;
    if (utterance != null && !utterance.liveDone) {
      utterance.liveDone = true;
      utterance.insertIndex ??= state.messages.length;
      _trySaveUtterance(utterance);
    }
  }

  /// Příjem chybové zprávy z WebSocketu.
  ///
  /// Chyba hovor ukončí (UI pak nabízí jen nový start), proto lekci rovnou uzavřeme,
  /// aby se přepis uložil a spustila se analýza – jinak by zůstala otevřená a nevyhodnocená.
  void _onError(String error) {
    state = state.copyWith(status: TutorState.error, errorMessage: error);
    stopSession('error: $error').then((_) {
      if (ref.mounted) {
        state = state.copyWith(status: TutorState.error, errorMessage: error);
      }
    });
  }

  /// Po výpadku a znovupřipojení WebSocketu injektuje do nové relace Gemini
  /// living executive summary od VoiceDirectorAgenta, aby model neztratil nit ani v dlouhém hovoru.
  void _restoreConversationContext(GeminiLiveClient client) {
    try {
      final executiveBriefing = _director.getExecutiveBriefingForReconnect(
        recentMessages: state.messages,
      );

      L.i('Obnovuji kontext konverzace po reconnectu s využitím living executive summary z VoiceDirectorAgenta...');
      L.director('Obnovuji kontext konverzace po reconnectu s využitím living executive summary...');
      L.block('RECONNECT', 'Living Executive Briefing (Kontext pro obnovené spojení)', executiveBriefing);

      client.sendClientContent(
        role: 'user',
        text: executiveBriefing,
        turnComplete: false,
      );
    } catch (e) {
      L.w('Chyba při obnově kontextu po reconnectu: $e');
    }
  }

  /// Bezpečně ukončí aktuální hlasové sezení a spustí asynchronní vyhodnocení.
  ///
  /// [reason] označuje důvod odpojení (pro účely logování).
  /// Souběžná volání čekají na jedno společné ukončení.
  Future<void> stopSession([String reason = 'unknown']) {
    return _pendingStop ??=
        _stopSession(reason).whenComplete(() => _pendingStop = null);
  }

  Future<void> _stopSession(String reason) async {
    L.i('Ukončování session (Důvod: $reason)');
    _isStopping = true;
    _sessionGeneration++;

    try {
      // Zrušení časovačů
      _timers.cancelAll();
      _turnCompleteReceived = false;
      _userSpokeInCurrentTurn = false;
      _pendingGuidance.clear();
      _vad.reset();

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
            liveClient.muteOutput = false;
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

        // Repliky studenta: rozpracovaná řeč i repliky čekající na opravný přepis
        // se uloží před uzavřením lekce, aby je viděl rozbor po lekci
        await _settleStudentUtterances();

        // Živý přepis bez nahrané repliky
        if (_currentUserTranscript.trim().isNotEmpty && _lastUtterance == null) {
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
        }
        _currentUserTranscript = '';
        _resetSpeechActivity();

        // Pokud model zrovna mluvil a nestihl odeslat turnComplete, flushneme rozpracovaný text
        if (ref.mounted && hasSpokenWords(state.currentTranscript)) {
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

        // ─── SESSION SUMMARY ───
        _metrics.logSummary(sessionId);
        
        _currentSessionId = null;
        if (ref.mounted) {
          _director.reset();
        }


        // Spuštění asynchronní Structured Outputs analýzy na pozadí přes MemoryManagerAgent.
        // Log lekce se zavře až po ní, aby obsahoval i výsledek nebo chybu analýzy.
        _memory.analyzeSession(sessionId).catchError((e, stack) {
          L.e('Chyba při spouštění analýzy na pozadí', e, stack);
        }).whenComplete(() => L.endSessionLog(sessionId));
      }
    } catch (globalError, stack) {
      L.e('Neočekávaná chyba při ukončování session', globalError, stack);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          status: TutorState.idle,
          currentTranscript: '',
          clearScenario: true,
        );
        L.i('UI resetováno do stavu idle');
      }
      _isStopping = false;
    }
  }

  /// Uloží všechny rozpracované repliky studenta. Na opravný přepis počká nejvýš 8 s,
  /// potom se uloží živý přepis.
  Future<void> _settleStudentUtterances() async {
    if (_activityOpen) _closeActivity(null);
    for (final utterance in List.of(_pendingUtterances)) {
      utterance.liveDone = true;
      _trySaveUtterance(utterance);
    }
    if (_pendingUtterances.isEmpty) return;

    L.i('Čekám na opravný přepis ${_pendingUtterances.length} replik studenta...');
    await Future.wait(_pendingUtterances.map((u) => u.settled))
        .timeout(const Duration(seconds: 8), onTimeout: () => const <void>[]);
    for (final utterance in List.of(_pendingUtterances)) {
      L.w('Opravný přepis nedoběhl, ukládám živý přepis repliky.');
      utterance.correctionDone = true;
      _trySaveUtterance(utterance);
    }
  }

  /// Aktuální stav tutora pro bezpečný přístup mimo ref (např. v dispose).
  TutorState get currentStatus => state.status;

  /// Pozastaví probíhající konverzaci.
  ///
  /// Zastaví mikrofon, ale ponechá WebSocket otevřený pro rychlé obnovení.
  /// Wakelock zůstává zapnutý, aby se displej nezhasil.
  Future<void> pauseSession() async {
    if (state.status == TutorState.idle || state.status == TutorState.error || state.status == TutorState.paused) return;

    L.i('Pozastavuji konverzaci...');
    HapticFeedback.lightImpact();

    _flushUserTranscript();

    // Zastavíme watchdog a ostatní časovače, aby nespustily reconnect během pauzy
    _timers.cancelAll();
    _turnCompleteReceived = false;
    // Rozpracovaná řeč studenta zůstane otevřená: po obnovení může větu dokončit,
    // a když bude mlčet, konec řeči se ohlásí po obvyklém tichu.
    _userSpokeInCurrentTurn = _activityOpen;
    _preRoll.clear();

    // Zbytek rozpracované odpovědi tutora se během pauzy nepřehraje
    ref.read(geminiLiveClientProvider)?.muteOutput = true;

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
    client.muteOutput = false;
    _preRoll.clear();

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

  /// Okamžitě přeruší probíhající řeč tutora a vrátí aplikaci do stavu poslechu (listening).
  ///
  /// Slouží pro manuální převzetí slova studentem (např. klepnutím na zvukovou vlnu v UI),
  /// pokud tutor začal mluvit předčasně nebo student chce pokračovat ve své myšlence.
  void interruptPlayback() {
    if (state.status != TutorState.speaking && !_audio.isPlaying) return;

    L.i('Manuální přerušení řeči tutora studentem (barge-in tap).');
    HapticFeedback.mediumImpact();

    _timers.cancel(TutorTimer.playbackComplete);
    _timers.cancel(TutorTimer.stuck);
    _audio.stopPlayback();
    _director.dismissTip();

    // Bezpečně uložíme částečný přepis tutora, pokud již dorazil
    _commitPartialTutorTranscript(status: TutorState.listening);

    _turnCompleteReceived = false;
    _userSpokeInCurrentTurn = false;
  }

  /// Odešle manuální textovou zprávu namísto mluvení (podpora chat režimu).
  void sendText(String text) {
    if (text.trim().isEmpty) return;

    _resetWatchdog();
    final client = ref.read(geminiLiveClientProvider);
    if (client != null && state.status != TutorState.idle && state.status != TutorState.error && state.status != TutorState.paused) {
      // Rozpracovaná řeč se uzavře, napsaný text je samostatný tah
      _closeActivity(client);
      _userSpokeInCurrentTurn = false;
      _flushUserTranscript(); // Flush voice transcript if any was in progress

      // Přepneme stav do 'thinking', dokud AI neodpoví
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text, isUser: true)],
        status: TutorState.thinking,
      );
      _resetThinkingTimer();
      client.sendText(text);

      // Uložení manuálního textu do DB
      _saveTranscript('user', text.trim());
    }
  }

  /// Dynamická injekce instrukcí v reálném čase.
  ///
  /// Slouží k vynucenému řízení témat a prevenci repetice uprostřed běžícího hovoru
  /// přes strukturu BidiGenerateContentClientContent protokolu WebSocket.
  /// Pokud je [turnComplete] `true`, pokyn se odešle hned a model okamžitě odpoví
  /// (případnou rozpracovanou odpověď tím záměrně přeruší).
  /// Pokud je `false`, pokyn počká na konec tahu tutora ([_flushPendingGuidance]),
  /// aby tutora neutnul uprostřed věty, a model ho absorbuje do kontextu.
  void injectMidSessionGuidance(String hiddenInstruction, {bool turnComplete = false}) {
    if (!turnComplete) {
      _pendingGuidance.add(hiddenInstruction);
      L.i('Skrytý pokyn čeká na konec tahu tutora (ve frontě: ${_pendingGuidance.length}).');
      return;
    }
    _sendGuidance(hiddenInstruction, turnComplete: true);
  }

  /// Odešle pokyny, které čekaly na konec tahu tutora.
  void _flushPendingGuidance() {
    if (_pendingGuidance.isEmpty) return;
    final pending = List<String>.from(_pendingGuidance);
    _pendingGuidance.clear();
    for (final instruction in pending) {
      _sendGuidance(instruction, turnComplete: false);
    }
  }

  void _sendGuidance(String hiddenInstruction, {required bool turnComplete}) {
    final client = ref.read(geminiLiveClientProvider);

    if (client != null && client.isConnected && state.status != TutorState.idle) {
      L.i('Injektuji systémový mid-session update pro modifikaci pozornosti modelu (turnComplete: $turnComplete).');

      // Posíláme jako 'user' s prefixem, protože Gemini Live API
      // nepodporuje roli 'system' v clientContent po úvodním setupu.
      client.sendClientContent(
        role: 'user',
        text: LiveTutorPrompts.systemInstruction(hiddenInstruction),
        turnComplete: turnComplete,
      );
    }
  }

  /// Vynucená změna tématu konverzace.
  ///
  /// Volá se uživatelským tlačítkem "Změnit téma" ([promptImmediateResponse] = true)
  /// nebo heuristikou detekující nadměrnou sémantickou podobnost posledních tahů ([promptImmediateResponse] = false).
  void forceTopicChange({bool promptImmediateResponse = true}) {
    HapticFeedback.lightImpact();

    if (promptImmediateResponse) {
      final client = ref.read(geminiLiveClientProvider);
      if (client == null ||
          !client.isConnected ||
          state.status == TutorState.idle ||
          state.status == TutorState.error ||
          state.status == TutorState.connecting ||
          state.status == TutorState.reconnecting ||
          state.status == TutorState.thinking) {
        return;
      }

      // 1. Zastavíme případné probíhající přehrávání audia z reproduktoru a časovače
      _timers.cancel(TutorTimer.playbackComplete);
      _audio.stopPlayback();

      // 2. Pokud byl rozpracovaný transkript tutora, bezpečně ho uložíme do zpráv i do DB
      _commitPartialTutorTranscript();

      // 3. Uzavření rozpracované řeči a flush transkriptu uživatele
      _closeActivity(client);
      _userSpokeInCurrentTurn = false;
      _flushUserTranscript();

      // 4. Přepneme stav do thinking – AI ihned začne přemýšlet a generovat nové téma
      state = state.copyWith(
        status: TutorState.thinking,
        currentTranscript: '',
      );
      _resetThinkingTimer();
      _resetWatchdog();

      // 5. Odešleme systémovou instrukci s turnComplete: true pro okamžité převzetí slova modelem
      injectMidSessionGuidance(LiveTutorPrompts.changeTopicNow, turnComplete: true);
    } else {
      // Pasivní heuristická změna při detekci stagnace v pozadí (přepne se v příštím tahu studenta)
      injectMidSessionGuidance(LiveTutorPrompts.changeTopicSilently, turnComplete: false);
    }
  }

  /// Resetuje watchdog časovač aktivity.
  ///
  /// Pokud 45 sekund nedojde k žádné komunikaci (uživatel ani AI nemluví a neposílají zprávy),
  /// watchdog usoudí, že došlo k tichému rozpadu socketu a vyvolá bezpečný reconnect s obnovením kontextu.
  void _resetWatchdog() {
    _timers.start(TutorTimer.watchdog, const Duration(seconds: 45), () {
      if (state.status != TutorState.idle &&
          state.status != TutorState.error &&
          state.status != TutorState.paused &&
          state.status != TutorState.reconnecting &&
          state.status != TutorState.connecting) {
        L.w('Watchdog: Žádná aktivita 45s, zkouším reconnect s obnovením kontextu...');
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
    if (state.status == TutorState.listening || state.status == TutorState.thinking) {
      if (_audio.isPlaying) {
        if (!_muteLogged) {
          L.w('🔇 MUTE WINDOW: Zahazuji zvuk z mikrofonu (reproduktor ještě hraje)');
          _muteLogged = true;
        }
        // Ozvěna tutora nesmí skončit v úvodu další řeči studenta
        _preRoll.clear();
      } else {
        if (_muteLogged) {
          L.i('🎤 MUTE WINDOW KONČÍ: Mikrofon je opět aktivní.');
          _muteLogged = false;
        }

        // Detekce řeči může řeč právě otevřít (pak se nejdřív pošle úvod z PreRollBuffer)
        _processAudioChunkForVAD(data, client);
        if (_activityOpen) {
          client.sendAudioChunk(data);
          _utterance?.addAudio(data);
        } else {
          _preRoll.add(data);
        }
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

  /// PCM 16-bit, 16 kHz, mono: 32 bajtů na milisekundu.
  static const int _pcmBytesPerMs = 32;

  /// Kolik souvislého hlasu otevře řeč studenta. Krátké ruchy (klepnutí, nádech,
  /// dozvuk reproduktoru, 80–160 ms) ji otevíraly a živý přepis z nich dělal „¿Qué?“.
  static const int _minSpeechMs = 200;

  /// Přerušit přemýšlení tutora (a tím zrušit jeho rozpracovanou odpověď) chce víc jistoty.
  static const int _bargeInSpeechMs = 300;

  /// Lokální detekce hlasové aktivity (VAD) z PCM 16-bit audio proudu.
  ///
  /// Při souvislé řeči ohlásí serveru její začátek (activityStart) a po nastaveném
  /// tichu konec (activityEnd) – ten spustí odpověď modelu.
  void _processAudioChunkForVAD(List<int> buffer, GeminiLiveClient client) {
    if (buffer.length < 2) return;

    final volume = pcm16Volume(buffer);
    final durationMs = buffer.length ~/ _pcmBytesPerMs;

    // Šum okolí se odhaduje jen v klidovém poslechu, aby hlas studenta neposouval práh nahoru.
    final level = _vad.classify(
      volume,
      adaptNoiseFloor: !_userSpokeInCurrentTurn && state.status == TutorState.listening,
    );
    // Hlas začíná blokem řeči, doznívání (sustain) ho jen prodlužuje
    final voiced = level == VoiceLevel.speech || (level == VoiceLevel.sustain && _vad.isVoicing);

    // Pokud jsme ve stavu thinking (čekáme na odpověď AI):
    // Šum ani krátké ruchy přemýšlení nepřeruší. Teprve souvislá řeč studenta
    // vrátí stav do listening a otevře novou řeč (rozpracovanou odpověď tím zruší).
    if (state.status == TutorState.thinking) {
      if (!voiced) {
        _vad.resetVoiced();
      } else if (_vad.addVoiced(durationMs, minSpeechMs: _bargeInSpeechMs)) {
        L.i('Student přerušil přemýšlení tutora hlasovým vstupem (vol: ${volume.toStringAsFixed(3)} >= ${_vad.startThreshold.toStringAsFixed(3)}).');
        state = state.copyWith(status: TutorState.listening);
        _userSpokeInCurrentTurn = true;
        _timers.cancel(TutorTimer.thinking);
        _timers.cancel(TutorTimer.responseSilence);
        _resetWatchdog();
        _openActivity(client);
      }
      return;
    }

    if (voiced) {
      if (_vad.addVoiced(durationMs, minSpeechMs: _minSpeechMs)) {
        if (!_userSpokeInCurrentTurn) {
          _userSpokeInCurrentTurn = true;
          L.vad('Detekována řeč studenta (hlasitost: ${volume.toStringAsFixed(3)}, start práh: ${_vad.startThreshold.toStringAsFixed(3)}, šum: ${_vad.noiseFloor.toStringAsFixed(3)})');
        }
        _openActivity(client);
        // Student aktivně mluví – zrušíme všechny časovače čekání na odpověď či ticho
        if (_timers.isActive(TutorTimer.vadSilence)) {
          L.vad('Student pokračuje v mluvení, ruším časovač ticha');
          _timers.cancel(TutorTimer.vadSilence);
        }
        _timers.cancel(TutorTimer.responseSilence);
        _timers.cancel(TutorTimer.thinking);
        _resetWatchdog();
      }
    } else if (level == VoiceLevel.silence) {
      _vad.resetVoiced();
      if (_userSpokeInCurrentTurn && !_timers.isActive(TutorTimer.vadSilence)) {
        _startEndOfSpeechTimer(volume, client);
      }
    }
    // Měkké doznění bez předchozí řeči: časovač ticha nezačínáme, ale ani nerušíme běžící.
  }

  /// Po nastavené době ticha od domluvení studenta ohlásí konec řeči – model začne odpovídat.
  void _startEndOfSpeechTimer(double volume, GeminiLiveClient client) {
    // Nastavená trpělivost + rezerva na doznívání řeči pod prahem hlasitosti
    // (výchozích 1 500 ms → 2 s ticha). Server konec řeči sám neurčuje.
    final configuredPatience = ref.read(speechPatienceProvider);
    final vadWaitMs = configuredPatience + 500;
    L.vad('Hlasitost klesla pod práh (vol: ${volume.toStringAsFixed(3)} < ${_vad.holdThreshold.toStringAsFixed(3)}), spouštím časovač ticha ${vadWaitMs}ms...');
    _timers.start(TutorTimer.vadSilence, Duration(milliseconds: vadWaitMs), () {
      if ((state.status == TutorState.listening || state.status == TutorState.thinking) && _userSpokeInCurrentTurn) {
        _userSpokeInCurrentTurn = false;

        L.vad('Konec řeči studenta (${vadWaitMs}ms ticho po domluvení). Ohlašuji konec řeči...');
        _closeActivity(client);
        state = state.copyWith(status: TutorState.thinking);
        _resetThinkingTimer();
        _resetResponseSilenceTimer();
      }
    });
  }

  /// Hlídá, že model po konci řeči studenta začne odpovídat.
  ///
  /// Konec řeči ohlašuje aplikace, takže odpověď má přijít hned. Když do 11 s nedorazí
  /// žádné audio ani text, spojení se obnoví s kontextem.
  void _resetResponseSilenceTimer() {
    _timers.start(TutorTimer.responseSilence, const Duration(seconds: 11), () {
      if ((state.status == TutorState.listening || state.status == TutorState.thinking) && !_userSpokeInCurrentTurn) {
        final client = ref.read(geminiLiveClientProvider);
        if (client != null && client.isConnected) {
          L.w('Model nereaguje 11 s po konci řeči studenta. Vyvolávám forceReconnect...');
          state = state.copyWith(status: TutorState.reconnecting);
          client.forceReconnect();
        }
      }
    });
  }

  /// Resetuje a konfiguruje stuck timer pro stav 'speaking'.
  ///
  /// Pokud se tutor přepne do stavu `speaking` (má mluvit), ale během 6 sekund
  /// nedorazí žádný další audio chunk ani turnComplete signál, stuck timer
  /// vrátí tutora zpět do stavu `listening`, aby se konverzace neodepsala.
  void _resetStuckTimer() {
    _timers.cancel(TutorTimer.stuck);
    if (state.status == TutorState.speaking) {
      _timers.start(TutorTimer.stuck, const Duration(seconds: 6), () {
        if (state.status == TutorState.speaking) {
          if (_audio.isPlaying) {
             L.i('Stuck timer: Audio ještě hraje, odkládám reset o dalších 3s.');
             _resetStuckTimer();
          } else {
             L.w('Detekováno zaseknutí ve stavu speaking (reproduktor už nehraje), vracím do listening.');
             state = state.copyWith(status: TutorState.listening);
             _turnCompleteReceived = false;
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
    _timers.cancel(TutorTimer.thinking);
    if (state.status == TutorState.thinking) {
      _timers.start(TutorTimer.thinking, const Duration(seconds: 15), () {
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
