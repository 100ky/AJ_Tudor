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
import '../../data/models/error_category.dart';
import '../../data/models/progress_trends.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../prompt/live_tutor_prompts.dart';
import '../prompt/system_prompt_builder.dart';
import '../audio/audio_session_controller.dart';
import '../flashcards/conversation_cards.dart';
import '../flashcards/due_conversation_cards.dart';
import '../flashcards/lesson_card_judge.dart';
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
  /// Kartičky, které student v této lekci splnil v hovoru.
  final List<ConversationCard> completedCards;
  /// Student si pro příští hovor vybral lekci s kartičkami (záložka „Lekce“).
  final bool lessonMode;
  /// Výrazy probíhající lekce v pořadí, v jakém je tutor projde; v pokecu prázdné.
  final List<ConversationCard> lessonCards;
  /// Lekce skončila (všechny výrazy splněné nebo vypršel čas), hovor pokračuje pokecem.
  final bool lessonFinished;

  /// Vytvoří výchozí nebo specifický stav Voice Tutora.
  VoiceTutorState({
    this.status = TutorState.idle,
    this.currentTranscript = '',
    this.messages = const [],
    this.errorMessage = '',
    this.selectedScenarioId,
    this.scenarioContext,
    this.completedCards = const [],
    this.lessonMode = false,
    this.lessonCards = const [],
    this.lessonFinished = false,
  });

  /// Kolik výrazů lekce student už řekl sám.
  int get lessonCompleted =>
      lessonCards.where((card) => completedCards.any((done) => done.id == card.id)).length;

  /// Vytvoří kopii aktuálního stavu s modifikovanými vlastnostmi.
  VoiceTutorState copyWith({
    TutorState? status,
    String? currentTranscript,
    List<ChatMessage>? messages,
    String? errorMessage,
    int? selectedScenarioId,
    String? scenarioContext,
    bool clearScenario = false,
    List<ConversationCard>? completedCards,
    bool? lessonMode,
    List<ConversationCard>? lessonCards,
    bool? lessonFinished,
  }) {
    return VoiceTutorState(
      status: status ?? this.status,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedScenarioId: clearScenario ? null : (selectedScenarioId ?? this.selectedScenarioId),
      scenarioContext: clearScenario ? null : (scenarioContext ?? this.scenarioContext),
      completedCards: completedCards ?? this.completedCards,
      lessonMode: lessonMode ?? this.lessonMode,
      lessonCards: lessonCards ?? this.lessonCards,
      lessonFinished: lessonFinished ?? this.lessonFinished,
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

  // Úvodní replika tutora; pošle se po 1 s, pokud student nezačal mluvit sám.
  String? _pendingOpener;

  // Délka aktuálního souvislého hlasu se do repliky započítala (první blok běhu přidá celý začátek).
  bool _voiceRunCounted = false;

  // Student domluvil a model zatím neodpověděl (ani na jeho další repliky). Lhůta na odpověď
  // běží od první nezodpovězené repliky (viz _awaitResponse).
  bool _awaitingResponse = false;
  bool _responseOverdue = false;

  // Spojení spadlo uprostřed hovoru a nové ještě nedostalo kontext. Podle stavu na displeji
  // se to poznat nedá: replika studenta ověřená během obnovy ho přepnula z reconnecting na
  // thinking a nové spojení pak kontext nedostalo (lekce 22: tutor znovu pozdravil).
  bool _reconnectPending = false;

  /// Jak dlouho od první nezodpovězené repliky studenta smí model mlčet.
  static const Duration _responseTimeout = Duration(seconds: 11);

  /// Kolik času dostane model na odpověď na každou další repliku. Běžně odpoví
  /// do 1–2 s, nejpomalejší odpověď v logu lekcí přišla za 4 s.
  static const Duration _responseGrace = Duration(seconds: 5);

  /// Kolikrát smí student promluvit mezi spuštěním režiséra a příchodem jeho rady.
  /// Rada vzniká po tahu tutora a předá se po dalším, takže jedna replika studenta je běžná.
  static const int _maxStudentTurnsForWhisper = 1;

  /// Kolik výrazů z kartiček projde jedna lekce (režim Lekce).
  static const int lessonCardCount = 10;

  /// Kolik minut nejvýš lekce trvá, pak ji tutor uzavře a hovor pokračuje pokecem.
  static const int lessonMinutes = 15;

  /// Délka lekce (testy ji zkracují).
  @visibleForTesting
  static Duration lessonDuration = const Duration(minutes: lessonMinutes);

  DateTime? _lessonStartedAt;

  /// Probíhá lekce s kartičkami (ještě neskončila).
  bool get _lessonRunning => state.lessonCards.isNotEmpty && !state.lessonFinished;

  /// Počet replik studenta v aktuální lekci (z bublin chatu).
  int get _studentTurnCount => state.messages.where((m) => m.isUser).length;

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
  late final FlashcardRepository _flashcardRepo;
  late final ScenarioRepository _scenarioRepo;
  late final MemoryManagerAgent _memory;
  late final VoiceDirectorAgent _director;
  late final SpeechTranscriptionService _transcriber;

  String _targetLevelSnapshot = 'B1';
  String? _userFactsSnapshot;
  String? _recentTopicsSnapshot;

  // Dnešní kartičky, které může splnit tento hovor (null = nenačetly se, hovor běží bez nich)
  ConversationCards? _conversationCards;
  int? _conversationCardsSessionId;

  @override
  VoiceTutorState build() {
    // Inicializace závislých služeb přes Riverpod
    _wakelock = ref.read(wakelockServiceProvider);
    _audio = ref.read(audioSessionControllerProvider);
    _repo = ref.read(sessionRepositoryProvider);
    _profileRepo = ref.read(profileRepositoryProvider);
    _flashcardRepo = ref.read(flashcardRepositoryProvider);
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
      if (this.state.status == TutorState.idle) unawaited(_retryAnalysesWithoutNetwork());
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

  bool _retryingAnalyses = false;

  /// Zopakuje rozbor lekcí, kterým po konci hovoru chyběla síť. Jen mimo hovor,
  /// výsledek se připíše do logu lekce.
  Future<void> _retryAnalysesWithoutNetwork() async {
    if (_retryingAnalyses) return;
    _retryingAnalyses = true;
    try {
      for (final sessionId in _memory.analysesAwaitingNetwork) {
        if (!ref.mounted || state.status != TutorState.idle) break;
        L.i('Aplikace je zpět v popředí, opakuji rozbor lekce $sessionId (předtím chyběla síť).');
        await L.startSessionLog(sessionId);
        await _memory.analyzeSession(sessionId);
        await L.endSessionLog(sessionId);
      }
    } catch (e, stack) {
      L.e('Chyba při opakování rozboru lekce', e, stack);
    } finally {
      _retryingAnalyses = false;
    }
  }

  /// Nastaví aktivní scénář a jeho roli pro aktuální lekci.
  void selectScenario(int id, String context) {
    if (id == 0 || context.trim().isEmpty) {
      state = state.copyWith(clearScenario: true, lessonMode: false);
    } else {
      state = state.copyWith(selectedScenarioId: id, scenarioContext: context, lessonMode: false);
    }
  }

  /// Vybere pro příští hovor lekci s dnešními kartičkami (místo tématu nebo scénáře).
  void selectLesson() {
    state = state.copyWith(clearScenario: true, lessonMode: true);
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
      completedCards: const [],
      lessonCards: const [],
      lessonFinished: false,
    );
    _conversationCards = null;
    _lessonStartedAt = null;
    _conversationCardsSessionId = null;
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
      final conversationCards = await _loadConversationCards();
      // Stop během čekání na DB už lekci uzavřel – hovor bez lekce by se neuložil ani nevyhodnotil
      if (_isStartCancelled(generation)) return;
      _conversationCards = conversationCards;
      _conversationCardsSessionId = newSessionId;

      // Lekce projde nejdéle čekající kartičky, které hovor dokáže ověřit
      final lessonCards = state.lessonMode
          ? (conversationCards?.cards.take(lessonCardCount).toList() ?? const <ConversationCard>[])
          : const <ConversationCard>[];
      if (state.lessonMode && lessonCards.isEmpty) {
        L.w('🎓 Lekce: na dnešek nejsou kartičky, které by šly procvičit v hovoru. Hovor poběží jako pokec.');
      }
      if (lessonCards.isNotEmpty) {
        L.i('🎓 Lekce: ${lessonCards.length} výrazů (${lessonCards.map((c) => c.english).join(', ')}).');
        _lessonStartedAt = DateTime.now();
      }
      state = state.copyWith(lessonCards: lessonCards, lessonFinished: false);
      // Gramatický cíl lekce: nejčastější gramatická chyba z posledních lekcí
      final lessonGoal = lessonCards.isEmpty ? null : await _loadGrammarGoal();
      if (lessonGoal != null) L.i('🎓 Gramatický cíl lekce: ${lessonGoal.label}.');
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
        lessonCards: state.lessonCards,
        grammarGoal: lessonGoal,
      );

      // ─── STRUKTUROVANÉ LOGOVÁNÍ STARTU SESSION ───
      final scenarioLabel = state.lessonCards.isNotEmpty
          ? 'Lekce s kartičkami (${state.lessonCards.length} výrazů)'
          : state.scenarioContext == '__free_talk__'
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
      final prepTopicJson = userProfile?.preparedTopic;
      String? preparedOpener;
      if (prepTopicJson != null && prepTopicJson.isNotEmpty) {
        try {
          final data = jsonDecode(prepTopicJson);
          preparedOpener = data['openerEn']?.toString();
        } catch (_) {}
      }
      _pendingOpener = LiveTutorPrompts.opening(
        scenarioContext: state.scenarioContext,
        preparedOpener: preparedOpener,
        briefing: userProfile?.memoryBriefing,
        lesson: state.lessonCards.isNotEmpty,
      );
      Future.delayed(const Duration(milliseconds: 1000), _trySendOpener);


    } catch (e, stack) {
      L.e('Chyba startu session', e, stack);
      state = state.copyWith(status: TutorState.error, errorMessage: 'Neočekávaná chyba při startu: $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Kartičky na dnešní opakování, které může splnit hovor (výslovnost hovor neověří).
  /// Když se nenačtou, hovor běží bez nich.
  Future<ConversationCards?> _loadConversationCards() async {
    try {
      final due = await _flashcardRepo.getDueFlashcards();
      final cards = conversationCardsFromDue(due);
      L.i('🃏 Kartičky pro hovor: ${cards.cards.length} z ${due.length} dnešních '
          '(režisér dostane nejvýš ${ConversationCards.poolSize}).');
      return cards;
    } catch (e) {
      L.w('Kartičky pro hovor se nenačetly, hovor poběží bez nich: $e');
      return null;
    }
  }

  /// Nejčastější gramatický druh chyby z posledních lekcí; null, když ještě není z čeho.
  Future<ErrorCategory?> _loadGrammarGoal() async {
    try {
      return ProgressTrends.grammarGoal(await _repo.getRecentCategorizedErrors());
    } catch (e) {
      L.w('Gramatický cíl lekce se nenačetl: $e');
      return null;
    }
  }

  /// Zkontroluje, jestli student v replice sám řekl výraz z některé dnešní kartičky.
  /// Splněná kartička dostane hodnocení „Dobré“ a dnes už v kartičkách nebude.
  ///
  /// V lekci, když doslovné porovnání nic nenašlo, posoudí repliku rozhodčí lekce:
  /// gramatiku student splní i vlastními slovy a slovíčko i v jiném tvaru.
  void _checkConversationCards(StudentUtterance utterance, String text) {
    final cards = _conversationCards;
    if (cards == null || utterance.sessionId != _conversationCardsSessionId) return;
    final done = cards.completeBy(text, recentTutorLines: utterance.recentTutorLines);
    _recordCompletedCards(done);
    final lessonIds = {for (final card in state.lessonCards) card.id};
    if (_lessonRunning && !done.any((card) => lessonIds.contains(card.id))) {
      _judgeLessonReply(utterance, text);
    }
  }

  /// Rozhodčí lekce posoudí repliku [text] proti kartičkám lekce, které ještě nejsou splněné.
  Future<void> _judgeLessonReply(StudentUtterance utterance, String text) async {
    final remaining = [
      for (final card in state.lessonCards)
        if (!state.completedCards.any((done) => done.id == card.id)) card,
    ];
    if (remaining.isEmpty) return;
    final card = await ref.read(lessonCardJudgeProvider).judge(
          remaining: remaining,
          recentTutorLines: utterance.recentTutorLines,
          studentText: text,
        );
    if (card == null || !ref.mounted || !_lessonRunning) return;
    if (utterance.sessionId != _conversationCardsSessionId) return;
    if (!(_conversationCards?.markCompleted(card) ?? false)) return;
    _recordCompletedCards([card]);
  }

  /// Zapíše splněné kartičky: hodnocení „Dobré“, stav pro obrazovku a průběh lekce.
  void _recordCompletedCards(List<ConversationCard> done) {
    if (done.isEmpty) return;
    for (final card in done) {
      L.i('🃏 Kartička #${card.id} splněna v hovoru: "${card.czech}" → "${card.english}"');
      _flashcardRepo.reviewFlashcard(flashcardId: card.id, rating: 2).then((result) {
        if (result.isFailure) L.w('Splněnou kartičku #${card.id} se nepodařilo uložit.');
      });
    }
    if (ref.mounted) {
      state = state.copyWith(completedCards: [...state.completedCards, ...done]);
      _reportLessonProgress(done);
    }
  }

  /// Splněný výraz z lekce: tutor se skrytě dozví, co zbývá. Po posledním lekce končí.
  void _reportLessonProgress(List<ConversationCard> done) {
    if (!_lessonRunning) return;
    final lessonIds = {for (final card in state.lessonCards) card.id};
    if (!done.any((card) => lessonIds.contains(card.id))) return;
    L.i('🎓 Lekce: splněno ${state.lessonCompleted}/${state.lessonCards.length}.');
    final note = _lessonProgressNote();
    if (state.lessonCompleted == state.lessonCards.length) {
      _finishLesson(note);
    } else {
      injectMidSessionGuidance(note);
    }
  }

  /// Skrytá zpráva tutorovi, které výrazy lekce student už řekl a které zbývají.
  String _lessonProgressNote() {
    final doneIds = {for (final card in state.completedCards) card.id};
    // Gramatickou kartičku tutor zná jen česky (anglické znění by vkládal do otázek)
    String label(ConversationCard card) => card.kind == CardKind.grammar ? card.czech : card.english;
    return LiveTutorPrompts.lessonProgress(
      done: [for (final card in state.lessonCards) if (doneIds.contains(card.id)) label(card)],
      remaining: [for (final card in state.lessonCards) if (!doneIds.contains(card.id)) label(card)],
    );
  }

  /// Po [lessonDuration] tutor lekci uzavře (zkontroluje se na konci jeho tahu).
  void _checkLessonTime() {
    final started = _lessonStartedAt;
    if (!_lessonRunning || started == null) return;
    if (DateTime.now().difference(started) < lessonDuration) return;
    L.i('🎓 Lekce: vypršel čas (${lessonDuration.inMinutes} min), tutor ji uzavře.');
    _finishLesson(LiveTutorPrompts.lessonTimeUp);
  }

  /// Lekce skončila: tutor ji uzavře a hovor dál běží jako pokec (zase s režisérem).
  void _finishLesson(String note) {
    state = state.copyWith(lessonFinished: true);
    injectMidSessionGuidance(note);
  }

  /// Poslední repliky tutora (i ta, kterou právě říká) pro kontrolu kartiček.
  List<String> _recentTutorLines() {
    final lines = <String>[
      if (state.currentTranscript.trim().isNotEmpty) state.currentTranscript,
    ];
    for (final message in state.messages.reversed) {
      if (lines.length >= ConversationCards.tutorLinesChecked) break;
      if (!message.isUser) lines.add(message.text);
    }
    return lines;
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
      // Živý přepis bývá u delší řeči (zvlášť české) zkomolený na „¿Qué?“ apod. Dlouhá nahrávka
      // nebo přepis v cizím písmu proto není krátká odpověď – student mluvil, jen se špatně přepsal.
      final spokeAtLength = utterance != null && utterance.audioMs >= 3000;
      final wordCount =
          (spokeAtLength || looksLikeForeignTranscription(userText)) ? null : meaningfulWordCount(userText);

      if (spokeAtLength) _consecutiveShortAnswers = 0;

      if (wordCount != null) {
        // ─── METRIKA: délka odpovědi uživatele ───
        _metrics.recordUserAnswer(wordCount);

        // V lekci jsou krátké odpovědi běžné (student řekne výraz z kartičky)
        if (wordCount <= 3 && !_lessonRunning) {
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

  /// Pošle úvodní repliku tutora, dokud student nezačal mluvit sám.
  void _trySendOpener() {
    final opener = _pendingOpener;
    if (opener == null || !ref.mounted) return;
    final client = ref.read(geminiLiveClientProvider);
    if (client == null ||
        !client.isConnected ||
        state.status != TutorState.listening ||
        _activityOpen ||
        _utterance != null) {
      return;
    }
    _pendingOpener = null;
    state = state.copyWith(status: TutorState.thinking);
    _resetThinkingTimer();
    client.sendText(opener);
  }

  /// Začne nahrávat repliku studenta i s úvodem zachyceným před zjištěnou řečí.
  /// Serveru se zatím nic neposílá – to až u dost dlouhé, nebo ověřené řeči.
  void _beginUtterance() {
    if (_utterance != null) return;
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    final utterance = StudentUtterance(sessionId: sessionId)
      ..previousTutorLine = _lastTutorLine()
      ..recentTutorLines = _recentTutorLines();
    _pendingUtterances.add(utterance);
    _utterance = utterance;
    for (final chunk in _preRoll.drain()) {
      utterance.addUnsent(chunk);
    }
  }

  /// Ohlásí serveru začátek řeči studenta a pošle vše, co se z repliky zatím nahrálo.
  void _openActivity(GeminiLiveClient client) {
    final pending = _utterance;
    if (_activityOpen || pending == null || !client.sendActivityStart()) return;
    _activityOpen = true;
    _pendingOpener = null; // student začal sám, úvod tutora už nepatří

    final unsent = pending.takeUnsent();
    for (final chunk in unsent) {
      client.sendAudioChunk(chunk);
    }

    final previous = _lastUtterance;
    if (previous != null && !identical(previous, pending) && !previous.liveDone && !previous.saved) {
      // Tutor ještě neodpověděl: pokračování patří do stejného tahu i stejné repliky
      previous.reopen();
      previous.voicedMs += pending.voicedMs;
      for (final chunk in unsent) {
        previous.addAudio(chunk);
      }
      _pendingUtterances.remove(pending);
      pending.markSettled();
      _utterance = previous;
    }

    if (state.status == TutorState.thinking) {
      // Rozpracovanou odpověď tutora activityStart zruší. Lhůta na odpověď běží dál:
      // když model mlčí, student se po chvíli ozve znovu („Haló?“).
      L.i('Student přerušil přemýšlení tutora hlasovým vstupem.');
      state = state.copyWith(status: TutorState.listening);
      _timers.cancel(TutorTimer.thinking);
    }
  }

  /// Zahodí nahranou repliku, která se serveru nikdy neposlala.
  void _discardPendingUtterance(String reason) {
    final utterance = _utterance;
    if (utterance == null || _activityOpen) return;
    L.i('🔇 $reason');
    _utterance = null;
    utterance.cancelVerification();
    _pendingUtterances.remove(utterance);
    utterance.saved = true;
    utterance.markSettled();
  }

  /// Ohlásí konec řeči studenta – model začne odpovídat.
  void _endStudentSpeech(GeminiLiveClient client) {
    _closeActivity(client);
    state = state.copyWith(status: _reconnectPending ? TutorState.reconnecting : TutorState.thinking);
    _resetThinkingTimer();
    _awaitResponse();
  }

  /// Krátká replika doběhla tichem a ověření je hotové: řeč (nebo nejasný výsledek)
  /// se Tudorovi pošle, ruch bez řeči se zahodí – Tudor na něj nereaguje.
  void _finishShortUtterance(StudentUtterance pending, int round, String? text, GeminiLiveClient client) {
    if (!ref.mounted ||
        !identical(_utterance, pending) ||
        _activityOpen ||
        !pending.isVerificationCurrent(round) ||
        _isPaused) {
      return;
    }
    if (text != null && text.isEmpty) {
      _discardPendingUtterance('Krátký ruch bez řeči (${pending.voicedMs} ms), Tudorovi ho neposílám.');
      _trySendOpener();
      return;
    }
    // Ověření poslouží rovnou jako opravný přepis
    if (text != null) {
      pending
        ..correctedText = text
        ..correctionDone = true;
    }
    L.vad('Krátká replika (${pending.voicedMs} ms) je řeč, posílám ji Tudorovi.');
    _openActivity(client);
    _endStudentSpeech(client);
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
    if (utterance.correctionDone) {
      // Krátká replika má přepis už z ověření
      _showUtteranceText(utterance);
      _trySaveUtterance(utterance);
    } else {
      _startCorrection(utterance);
    }
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
  ///
  /// Bez [withContext] se nepošle předchozí replika tutora.
  Future<String?> _correctedTranscript(StudentUtterance utterance, {bool withContext = true}) async {
    final audio = utterance.audioBytes();
    if (audio.isEmpty) return null;
    try {
      return await _transcriber
          .transcribe(audio, previousTutorLine: withContext ? utterance.previousTutorLine : null)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      L.w('Opravný přepis repliky selhal: $e');
      return null;
    }
  }

  /// Ověří, že je v krátké replice řeč studenta: prázdný text znamená ruch.
  ///
  /// Přepisuje se bez otázky tutora a delší přepis, než se do krátké repliky vejde,
  /// je výmysl. 9. 11. z 240 ms hlasu ženy telefonující vedle vznikla podle otázky
  /// tutora věta „Eh, so, they were changing at the same time?“ a Tudor na ni odpověděl.
  Future<String?> _verifyShortUtterance(StudentUtterance utterance) async {
    final text = await _correctedTranscript(utterance, withContext: false);
    if (text == null || text.isEmpty) return text;
    if (!SpeechTranscriptionService.fitsVoicedTime(text, utterance.voicedMs)) {
      L.w('Ověření krátké repliky: „$text“ se do ${utterance.voicedMs} ms hlasu nevejde, beru to jako ruch.');
      return '';
    }
    return text;
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
      _checkConversationCards(utterance, text);
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
    _pendingOpener = null;
    _voiceRunCounted = false;
    _utterance = null;
    _lastUtterance = null;
    _pendingUtterances.clear();
    _preRoll.clear();
    _stopAwaitingResponse();
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
    client.onActivityEndUnconfirmed = _onActivityEndUnconfirmed;
  }

  /// Server nepotvrdil konec řeči studenta: tah se ztratil a odpověď na něj nepřijde.
  /// Spojení se obnoví hned (jakmile student domluví), ne až po lhůtě na odpověď.
  void _onActivityEndUnconfirmed() {
    if (!_awaitingResponse) return;
    L.w('Server nepotvrdil konec řeči studenta, odpověď nepřijde.');
    _responseOverdue = true;
    _timers.cancel(TutorTimer.responseGrace);
    _reconnectIfUnanswered();
  }

  /// Příjem textové části odpovědi AI.
  void _onTextReceived(String text) {
    _timers.cancel(TutorTimer.thinking);
    _stopAwaitingResponse();
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
    _stopAwaitingResponse();
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
    _discardPendingUtterance('Tutor začal mluvit dřív, než se krátká replika ověřila – zahazuji ji.');
    _timers.cancel(TutorTimer.vadSilence);
    _userSpokeInCurrentTurn = false;
  }

  /// Události ze serveru (dokončený tah, přerušení) nesmí zrušit pauzu nastavenou studentem.
  TutorState _keepPaused(TutorState next) => _isPaused ? TutorState.paused : next;

  /// Konec promluvy tutora (turn complete).
  void _onTurnComplete(GeminiLiveClient client) {
    _resetWatchdog();
    _stopAwaitingResponse();
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

      // V lekci se tahy tutora podobají záměrně (pochvala a další výraz), téma se nemění
      if (similarity != null && !_lessonRunning) {
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

      // Věta k zopakování po opravě chyby se vypíchne na displeji (nebo zmizí, když tah
      // opravou nebyl). Režisér pak mlčí, dokud student větu nezopakuje.
      _director.setRepeatTarget(extractRepeatTarget(finalTutorText));
    } else {
      if (state.currentTranscript.isNotEmpty) {
        L.w('Tah tutora bez slov ("${state.currentTranscript}") – do přepisu ho neukládám.');
      }
      state = state.copyWith(currentTranscript: '', status: nextStatus);
    }

    _checkLessonTime();

    // Model domluvil – teď můžeme bezpečně předat skryté pokyny, aniž bychom ho utnuli
    _flushPendingGuidance();

    // Pokud reprák ještě hraje, počkáme, až dozní v audio handleru nebo v časovači; jinak jsme rovnou listening
    _turnCompleteReceived = isStillPlaying;
    if (isStillPlaying) {
      _resetStuckTimer();
      _scheduleListeningAfterPlayback();
    }

    // Asynchronní analýza a režie hovoru na pozadí (VoiceDirectorAgent). V lekci vede hovor
    // tutor podle kartiček a rada k tématu by ho od nich odváděla.
    if (_currentSessionId != null && state.messages.isNotEmpty && !_lessonRunning) {
      final studentTurnsAtStart = _studentTurnCount;
      _director.onTurnCompleted(
        sessionId: _currentSessionId!,
        messages: state.messages,
        targetLevel: _targetLevelSnapshot,
        userFacts: _userFactsSnapshot,
        recentTopics: _recentTopicsSnapshot,
        cards: _conversationCards?.directorPool() ?? const [],
        onWhisperReady: (whisper, card) {
          // Rada se předá až po dalším tahu tutora. Když mezitím student promluvil
          // víckrát, hovor je jinde (lekce 19: rada „přejdi na narozeniny“ dorazila
          // po pěti tazích, zrovna když se student loučil).
          final studentTurnsSince = _studentTurnCount - studentTurnsAtStart;
          if (studentTurnsSince > _maxStudentTurnsForWhisper) {
            L.i('VoiceDirector: Rada je zastaralá (student mezitím promluvil $studentTurnsSince×), zahazuji: "$whisper"');
            return;
          }
          L.i('VoiceDirector: Našeptávám tutorovi: "$whisper"');
          if (card != null) _conversationCards?.markWoven(card);
          injectMidSessionGuidance(
            LiveTutorPrompts.directorWhisper(whisper, cardTarget: card?.english),
            turnComplete: false,
          );
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
    _stopAwaitingResponse(); // model odpovídal, student ho přerušil
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
        _reconnectPending = true;
        state = state.copyWith(status: TutorState.reconnecting);
      } else if (state.status == TutorState.paused) {
        // Během dlouhé pauzy server spojení zavře pro nečinnost (1008) a klient ho sám
        // naváže znovu. Nové spojení musí dostat kontext, jinak tutor po obnovení zapomene
        // celý hovor (9. 11.). Pauza přitom zůstává.
        L.w('Spojení se během pauzy zavřelo, po připojení se obnoví kontext hovoru.');
        _reconnectPending = true;
      } else if (state.status == TutorState.connecting) {
        // Výpadek při inicializaci (např. 1007 od preview API) → zůstáváme v connecting
        L.w('Spojení uzavřeno při inicializaci. Auto-reconnect probíhá, zůstávám v connecting...');
      }
    } else if (isConnected &&
        (_reconnectPending || state.status == TutorState.reconnecting || state.status == TutorState.connecting)) {
      final wasReconnecting = _reconnectPending || state.status == TutorState.reconnecting;
      _reconnectPending = false;
      // Nové spojení rozpracovanou řeč nezná
      _dropActivityAfterDisconnect();
      // Na poslední repliku studenta staré spojení neodpovědělo, odpoví na ni tutor v novém
      final paused = state.status == TutorState.paused;
      final answerStudent = !paused && _awaitingResponse && (state.messages.lastOrNull?.isUser ?? false);
      _stopAwaitingResponse();
      if (paused) {
        L.i('Spojení obnoveno během pauzy, kontext hovoru pošlu a pauza zůstává.');
      } else {
        L.i('Spojení obnoveno, vracím se do stavu listening.');
        state = state.copyWith(status: TutorState.listening);
        _resetWatchdog();
      }

      // Pokud došlo k reconnectu během běžícího hovoru, obnovíme kontext do nové WebSocket relace
      if (wasReconnecting && state.messages.isNotEmpty) {
        _restoreConversationContext(client, answerStudent: answerStudent);
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
  ///
  /// S [answerStudent] tutor hned odpoví na poslední repliku studenta, na kterou
  /// staré spojení neodpovědělo. Jinak čeká, až student promluví.
  void _restoreConversationContext(GeminiLiveClient client, {bool answerStudent = false}) {
    try {
      var executiveBriefing = _director.getExecutiveBriefingForReconnect(
        recentMessages: state.messages,
      );
      // Nové spojení zná seznam výrazů ze systémového promptu, ne to, kam lekce došla
      if (_lessonRunning) {
        executiveBriefing += '\n${LiveTutorPrompts.systemInstruction(_lessonProgressNote())}';
      }

      L.i('Obnovuji kontext konverzace po reconnectu s využitím living executive summary z VoiceDirectorAgenta...');
      L.director('Obnovuji kontext konverzace po reconnectu s využitím living executive summary...');
      L.block('RECONNECT', 'Living Executive Briefing (Kontext pro obnovené spojení)', executiveBriefing);

      if (!answerStudent) {
        client.sendClientContent(
          role: 'user',
          text: executiveBriefing,
          turnComplete: false,
        );
        return;
      }

      L.i('Poslední replika studenta zůstala bez odpovědi, tutor na ni odpoví hned.');
      client.sendClientContent(
        role: 'user',
        text: '$executiveBriefing\n${LiveTutorPrompts.systemInstruction(LiveTutorPrompts.answerAfterReconnect)}',
        turnComplete: true,
      );
      state = state.copyWith(status: TutorState.thinking);
      _resetThinkingTimer();
      // Když nové spojení taky mlčí, lhůta ho po 11 s obnoví znovu
      _awaitResponse();
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
    _reconnectPending = false;

    try {
      // Zrušení časovačů
      _timers.cancelAll();
      _stopAwaitingResponse();
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
            liveClient.onActivityEndUnconfirmed = null;
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
        if (state.lessonCards.isNotEmpty) {
          L.i('🎓 Lekce: splněno ${state.lessonCompleted} z ${state.lessonCards.length} výrazů.');
        }
        final completedCards = _conversationCards?.completed ?? const <ConversationCard>[];
        if (completedCards.isNotEmpty) {
          L.i('🃏 V hovoru splněno kartiček: ${completedCards.length} '
              '(${completedCards.map((c) => c.english).join(', ')})');
        }
        
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
          lessonMode: false,
        );
        L.i('UI resetováno do stavu idle');
      }
      _isStopping = false;
    }
  }

  /// Uloží všechny rozpracované repliky studenta. Na opravný přepis počká nejvýš 8 s,
  /// potom se uloží živý přepis.
  Future<void> _settleStudentUtterances() async {
    final unsent = _utterance;
    if (_activityOpen) {
      _closeActivity(null);
    } else if (unsent != null) {
      // Krátká replika, která se Tudorovi nestihla poslat: uloží se, jen když je v ní řeč
      unsent.cancelVerification();
      _utterance = null;
      unsent.endedAt = DateTime.now();
      _lastUtterance = unsent;
      _startCorrection(unsent);
    }
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

  // Zapnutí a vypnutí mikrofonu při pauze a obnovení běží postupně v pořadí klepnutí.
  // Stav se přepne hned, takže rychlé druhé klepnutí udělá opak a mikrofon se nezapne
  // dřív, než se dokončí předchozí vypnutí (8. 11.: pauza a hned obnovení se zasekly).
  Future<void> _micChain = Future.value();

  Future<void> _queueMic(Future<void> Function() step) {
    final next = _micChain.then((_) => step());
    _micChain = next.catchError((Object _) {});
    return next;
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

    // Zastavíme watchdog a ostatní časovače, aby nespustily reconnect během pauzy
    _timers.cancelAll();
    _stopAwaitingResponse();
    _turnCompleteReceived = false;
    // Rozpracovaná řeč studenta zůstane otevřená: po obnovení může větu dokončit,
    // a když bude mlčet, konec řeči se ohlásí po obvyklém tichu.
    _userSpokeInCurrentTurn = _activityOpen || _utterance != null;
    _utterance?.cancelVerification();
    _preRoll.clear();

    // Zbytek rozpracované odpovědi tutora se během pauzy nepřehraje
    ref.read(geminiLiveClientProvider)?.muteOutput = true;
    state = state.copyWith(status: TutorState.paused);

    // Zastavíme mikrofon, ale necháme WebSocket otevřený
    await _queueMic(() async {
      try {
        await _audio.stop();
      } catch (e) {
        L.w('Chyba při pozastavení mikrofonu: $e');
      }
    });
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
    state = state.copyWith(status: TutorState.listening);

    // Znovu aktivujeme mikrofon bez ohledu na stav sítě,
    // aby mohl běžet na pozadí, jakmile se spojení obnoví.
    await _queueMic(() async {
      // Student mezitím zase pozastavil: mikrofon nechá vypnutý další krok ve frontě
      if (state.status != TutorState.listening) return;
      try {
        await _audio.start(onAudioChunk: (data) {
          _handleIncomingAudioChunk(data, client);
        });
      } catch (e) {
        L.e('Chyba mikrofonu při obnovení: $e');
        state = state.copyWith(status: TutorState.error, errorMessage: 'Chyba mikrofonu: $e');
        return;
      }
      if (state.status != TutorState.listening) return;
      if (!client.isConnected) {
        L.w('WebSocket je aktuálně odpojen, přecházím do stavu reconnecting a spouštím reconnect...');
        state = state.copyWith(status: TutorState.reconnecting);
        client.forceReconnect();
      }
      _resetWatchdog();
    });
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
      _discardPendingUtterance('Student píše, neodeslaná krátká replika se zahazuje.');
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
      _discardPendingUtterance('Změna tématu, neodeslaná krátká replika se zahazuje.');
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
          // Výpadek ohlásí sám klient, stav přepne na reconnecting
          ref.read(geminiLiveClientProvider)?.forceReconnect();
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
        } else if (_utterance != null) {
          // Krátká replika se nahrává a serveru se pošle až po ověření
          _utterance!.addUnsent(data);
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

  /// Od kolika souvislého hlasu je to jistě řeč a pošle se serveru hned. Kratší replika
  /// („yes“, ale i zakašlání nebo „hm“) se nejdřív ověří opravným přepisem – jinak Tudor
  /// reagoval i na ruch a živý přepis z něj dělal „¿Qué?“.
  static const int _confirmedSpeechMs = 700;

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

    if (voiced) {
      if (_vad.addVoiced(durationMs, minSpeechMs: _minSpeechMs)) {
        _onStudentVoice(durationMs, volume, client);
      }
    } else if (level == VoiceLevel.silence) {
      _vad.resetVoiced();
      _voiceRunCounted = false;
      if (_userSpokeInCurrentTurn && !_timers.isActive(TutorTimer.vadSilence)) {
        _startEndOfSpeechTimer(volume, client);
      }
    }
    // Měkké doznění bez předchozí řeči: časovač ticha nezačínáme, ale ani nerušíme běžící.
  }

  /// Student mluví: nahrává se replika a když má dost hlasu, otevře se řeč na serveru.
  void _onStudentVoice(int durationMs, double volume, GeminiLiveClient client) {
    if (!_userSpokeInCurrentTurn) {
      _userSpokeInCurrentTurn = true;
      L.vad('Detekována řeč studenta (hlasitost: ${volume.toStringAsFixed(3)}, start práh: ${_vad.startThreshold.toStringAsFixed(3)}, šum: ${_vad.noiseFloor.toStringAsFixed(3)})');
    }
    // Student aktivně mluví – zrušíme časovač ticha
    if (_timers.isActive(TutorTimer.vadSilence)) {
      L.vad('Student pokračuje v mluvení, ruším časovač ticha');
      _timers.cancel(TutorTimer.vadSilence);
    }
    _resetWatchdog();

    _beginUtterance();
    final utterance = _utterance;
    if (utterance == null) return;
    // Mluví dál: ověření ticha z předchozí pauzy už neplatí
    utterance.cancelVerification();
    utterance.voicedMs += _voiceRunCounted ? durationMs : _vad.voicedMs;
    _voiceRunCounted = true;

    if (!_activityOpen && utterance.voicedMs >= _confirmedSpeechMs) {
      _openActivity(client);
    }
    if (_activityOpen) {
      _timers.cancel(TutorTimer.thinking);
    }
  }

  /// Po nastavené době ticha od domluvení studenta ohlásí konec řeči – model začne odpovídat.
  void _startEndOfSpeechTimer(double volume, GeminiLiveClient client) {
    // Nastavená trpělivost + rezerva na doznívání řeči pod prahem hlasitosti
    // (výchozích 1 500 ms → 2 s ticha). Server konec řeči sám neurčuje.
    final configuredPatience = ref.read(speechPatienceProvider);
    final vadWaitMs = configuredPatience + 500;
    L.vad('Hlasitost klesla pod práh (vol: ${volume.toStringAsFixed(3)} < ${_vad.holdThreshold.toStringAsFixed(3)}), spouštím časovač ticha ${vadWaitMs}ms...');
    // Krátká replika se ověřuje už během ticha, ať je výsledek hotový, než ticho doběhne
    final pending = _utterance;
    if (pending != null && !_activityOpen) {
      pending.startVerification(_verifyShortUtterance(pending));
    }
    _timers.start(TutorTimer.vadSilence, Duration(milliseconds: vadWaitMs), () {
      if ((state.status == TutorState.listening || state.status == TutorState.thinking) && _userSpokeInCurrentTurn) {
        _userSpokeInCurrentTurn = false;

        final unsent = _utterance;
        if (unsent != null && !_activityOpen) {
          final verification = unsent.verification ??
              (unsent..startVerification(_verifyShortUtterance(unsent))).verification!;
          final round = unsent.verificationRound;
          L.vad('Konec krátké řeči (${unsent.voicedMs} ms hlasu). Čekám na ověření, že jde o řeč...');
          verification.then((text) => _finishShortUtterance(unsent, round, text, client));
          return;
        }

        L.vad('Konec řeči studenta (${vadWaitMs}ms ticho po domluvení). Ohlašuji konec řeči...');
        _endStudentSpeech(client);
      }
    });
  }

  /// Hlídá, že model po konci řeči studenta začne odpovídat.
  ///
  /// Konec řeči ohlašuje aplikace, takže odpověď má přijít hned. Lhůta 11 s běží od první
  /// nezodpovězené repliky: když model mlčí, student se po chvíli ozve znovu („Haló?“),
  /// a kdyby každá replika lhůtu vynulovala, nikdy by nedoběhla. Na každou další repliku
  /// má model aspoň 5 s. Pak se spojení obnoví s kontextem a tutor na repliku odpoví.
  void _awaitResponse() {
    if (!_awaitingResponse) {
      _awaitingResponse = true;
      _responseOverdue = false;
      _timers.start(TutorTimer.responseSilence, _responseTimeout, () {
        _responseOverdue = true;
        _reconnectIfUnanswered();
      });
    }
    _timers.start(TutorTimer.responseGrace, _responseGrace, _reconnectIfUnanswered);
  }

  /// Obnoví spojení, když lhůta na odpověď doběhla a model ani na poslední repliku neodpověděl.
  void _reconnectIfUnanswered() {
    if (!_awaitingResponse || !_responseOverdue || _timers.isActive(TutorTimer.responseGrace)) return;
    if (state.status != TutorState.listening && state.status != TutorState.thinking) return;
    if (_activityOpen || _userSpokeInCurrentTurn) {
      // Student právě mluví: spojení se neobnoví uprostřed jeho řeči. Po jejím konci
      // dostane model zase 5 s, zahozený ruch se ověří za sekundu.
      _timers.start(TutorTimer.responseGrace, const Duration(seconds: 1), _reconnectIfUnanswered);
      return;
    }
    final client = ref.read(geminiLiveClientProvider);
    if (client == null || !client.isConnected) return;
    L.w('Model neodpověděl na repliku studenta. Obnovuji spojení...');
    // Výpadek ohlásí sám klient, stav přepne na reconnecting
    client.forceReconnect();
  }

  /// Model odpovídá (nebo hovor skončil či se pozastavil): lhůta na odpověď už neběží.
  void _stopAwaitingResponse() {
    _awaitingResponse = false;
    _responseOverdue = false;
    _timers.cancel(TutorTimer.responseSilence);
    _timers.cancel(TutorTimer.responseGrace);
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
