import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/utils/logger.dart';
import '../audio/audio_playback_service.dart';

/// Klient pro obousměrnou real-time komunikaci s Gemini Live API přes WebSocket.
/// 
/// Zajišťuje odesílání hlasových (PCM 16-bit) a textových dat do Gemini a asynchronní
/// zpracování odpovědí (audio streamování zpět, transkripce řeči studenta i AI, tool calling atd.).
/// Obsahuje robustní automatickou logiku znovupřipojení s exponenciálním backoffem.
class GeminiLiveClient {
  /// Aktivní WebSocket kanál pro bidi-streamování.
  WebSocketChannel? _channel;

  /// Subscription pro stream WebSocketu (nutné pro explicitní odhlášení před zavřením).
  StreamSubscription? _channelSubscription;

  /// Časovač pro plánovaný pokus o znovupřipojení.
  Timer? _reconnectTimer;

  /// API klíč pro autentizaci vůči Gemini.
  final String _apiKey;

  /// Služba pro přehrávání přijatých audio dat.
  final AudioPlaybackService _playbackService;
  
  // Reconnect logika a stavové proměnné
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  bool _isManualDisconnect = false;
  bool _isReconnecting = false;
  String? _lastModelName;
  String? _lastSystemPrompt;
  String _lastVoiceName = 'Puck';

  // Pocitadlo po sobe jdoucich ridicich tokenu (ochrana pred zaseknutim v loopu)
  int _consecutiveControlTokens = 0;

  /// Vrací [bool] vyjadřující, zda je klient momentálně připojen a nemá aktivní pokusy o reconnect.
  bool get isConnected => _channel != null && _reconnectAttempts == 0 && !_isReconnecting;

  /// Vrací [bool], zda se zrovna v reproduktoru fyzicky přehrává zvuk AI.
  bool get isPlaybackPlaying => _playbackService.isPlaying;

  /// Přístup k audio playback službě.
  AudioPlaybackService get playbackService => _playbackService;

  // Callbacky pro předávání událostí do UI/agenta
  
  /// Vyvoláno při přijetí části textové odpovědi od tutora.
  Function(String)? onTextReceived;

  /// Vyvoláno při dokončení přepisu řeči uživatele (STT - Speech to Text).
  Function(String)? onUserTranscriptReceived;

  /// Vyvoláno při zahájení příjmu audia od tutora.
  Function()? onAudioReceived;

  /// Vyvoláno, když tutor dokončí svůj promluvový blok (turn complete).
  Function()? onTurnComplete;

  /// Vyvoláno při jakékoliv chybě v komunikaci.
  Function(String)? onError;

  /// Vyvoláno při změně stavu připojení (true = připojeno, false = odpojeno).
  Function(bool)? onConnectionStatusChanged;

  /// Vyvoláno, když model zavolá externí nástroj (Function Calling).
  Function(String name, Map<String, dynamic> args)? onToolCall;

  /// Vyvolano, když uživatel přeruší mluvení modelu (interruption).
  Function()? onInterrupted;

  /// Vyvoláno při aktualizaci počtu spotřebovaných tokenů (z usageMetadata).
  Function(int totalTokens)? onTokenCountUpdate;

  /// Konstruktor vyžadující API klíč a instanci služby přehrávání zvuku.
  GeminiLiveClient(this._apiKey, this._playbackService);

  /// Bezpečně uzavře stávající kanál a zruší listener, aby nespouštěl onDone při úmyslném zavření.
  void _closeCurrentChannel() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Naváže WebSocket spojení s Gemini Live API.
  /// 
  /// [modelName] definuje použitý model (např. gemini-2.0-flash-exp).
  /// [systemPrompt] předává instrukce pro chování tutora.
  /// [voiceName] určuje hlas pro syntézu řeči.
  /// [isReconnect] indikuje, zda jde o pokus o obnovení spadlého spojení.
  void connect({
    required String modelName,
    required String systemPrompt,
    String voiceName = 'Puck',
    bool isReconnect = false,
  }) {
    _isManualDisconnect = false;
    _lastModelName = modelName;
    _lastSystemPrompt = systemPrompt;
    _lastVoiceName = voiceName;
    
    // Zrušíme jakýkoliv čekající reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // Čištění starého spojení a jeho stream subscription, aby se nespustil falešný onDone
    _closeCurrentChannel();
    
    // Sestavení URI pro bidi-generate WebSocket.
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    // Maskovat API klíč v logu pro bezpečnost
    final maskedUri = uri.replace(queryParameters: {'key': '***'});
    L.i('Připojování k: $maskedUri');
    
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    // Naslouchání na příchozím streamu WebSocketu.
    _channelSubscription = channel.stream.listen(
      (message) {
        _reconnectAttempts = 0; // Resetujeme pokusy při úspěšném příjmu jakýchkoliv dat.
        _isReconnecting = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(true);

        // Diagnostické logování zpráv (pokud neobsahují obrovská binární data audia).
        if (message is String && !message.contains('inlineData') && !message.contains('inline_data')) {
          L.d('WebSocket PŘIJATO: $message');
        }
        _handleIncomingMessage(message);
      },
      onError: (error) {
        L.e('WebSocket CHYBA: $error');
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(false);
        _handleError(error.toString());
      },
      onDone: () {
        final code = channel.closeCode;
        final reason = channel.closeReason;
        L.w('WebSocket spojení UZAVŘENO. Code: $code, Reason: $reason');
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(false);
        
        // Pokud nebylo spojení zavřeno ručně uživatelem, pokusíme se o reconnect.
        if (!_isManualDisconnect) {
          _attemptReconnect();
        }
      },
    );

    // Odešleme SETUP zprávu až po plném otevření WebSocket kanálu.
    channel.ready.then((_) {
      if (_channel == channel) {
        _sendSetupMessage(modelName, systemPrompt, voiceName);
      }
    }).catchError((e) {
      L.e('WebSocket se nepodařilo otevřít: $e');
      if (!_isManualDisconnect) {
        _attemptReconnect();
      } else if (onError != null) {
        onError!('Nelze navázat spojení: $e');
      }
    });
  }

  /// Pokusí se o automatické znovupřipojení s exponenciálním backoffem (zabraňuje souběžným pokusům).
  void _attemptReconnect() {
    if (_isManualDisconnect) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      L.d('Reconnect timer již běží, přeskakuji duplicitní plánování.');
      return;
    }
    
    if (_reconnectAttempts < _maxReconnectAttempts && _lastModelName != null && _lastSystemPrompt != null) {
      _reconnectAttempts++;
      _isReconnecting = true;
      // Exponenciální prodleva mezi pokusy (2s, 4s, 6s, 8s, 10s).
      final delay = Duration(seconds: _reconnectAttempts * 2);
      L.i('Pokus o znovupřipojení č. $_reconnectAttempts za ${delay.inSeconds}s...');
      
      _reconnectTimer = Timer(delay, () {
        if (!_isManualDisconnect) {
          connect(
            modelName: _lastModelName!,
            systemPrompt: _lastSystemPrompt!,
            voiceName: _lastVoiceName,
            isReconnect: true,
          );
        }
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      _isReconnecting = false;
      L.e('Nepodařilo se obnovit spojení po $_maxReconnectAttempts pokusech.');
      if (onError != null) onError!('Nepodařilo se obnovit spojení po $_maxReconnectAttempts pokusech.');
    }
  }

  /// Vyhodnocuje chybové kódy a zprávy z WebSocketu.
  void _handleError(String errorMsg) {
    if (errorMsg.contains('429')) {
      if (onError != null) onError!('Překročena kvóta API (Rate limit). Zkuste to za chvíli.');
    } else if (errorMsg.contains('1008')) {
      L.w('GoAway detekován (kód 1008). Automatický reconnect se spustí z onDone.');
    } else {
      L.e('WebSocket CHYBA (nevyhazuji do UI, spoléhám na auto-reconnect): $errorMsg');
    }
  }

  /// Odešle počáteční SETUP zprávu pro definování modelu, hlasu, promptu a nástrojů (Function Calling).
  void _sendSetupMessage(String modelName, String systemPrompt, String voiceName) {
    final setupMessage = {
      'setup': {
        // Kontrola správného formátu názvu modelu
        'model': modelName.startsWith('models/') ? modelName : 'models/$modelName',
        'generationConfig': {
          'responseModalities': ['AUDIO'], // Chceme, aby model odpovídal primárně zvukem
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceName, 
              }
            }
          },
          // POZNÁMKA: contextWindowCompression není podporováno modelem gemini-3.1-flash-live-preview.
          // Pokud bude v budoucnu podporováno, přidat zpět:
          // 'contextWindowCompression': {
          //   'triggerTokens': 100000,
          //   'slidingWindow': { 'targetTokens': 80000 }
          // }
        },
        'systemInstruction': {
          'parts': [{'text': systemPrompt}]
        },
        // Povolíme transkripci jak pro vstup, tak pro výstup
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        // POZNÁMKA: sessionResumptionConfig není podporováno gemini-3.1-flash-live-preview.
        // Posílání tohoto pole způsobovalo 1007 smyčku po GoAway signálu — odstraněno.
        // Deklarace funkcí (Function Calling)
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': 'log_error',
                'description': 'Logs a linguistic error made by the student during the conversation.',
                'parameters': {
                  'type': 'OBJECT',
                  'properties': {
                    'error_type': {
                      'type': 'STRING', 
                      'enum': ['grammar', 'vocabulary', 'pronunciation'],
                      'description': 'The type of error.'
                    },
                    'user_said': {
                      'type': 'STRING',
                      'description': 'What the user actually said.'
                    },
                    'correct_form': {
                      'type': 'STRING',
                      'description': 'The correct version of the sentence/phrase.'
                    },
                    'explanation': {
                      'type': 'STRING',
                      'description': 'A short explanation in Czech.'
                    }
                  },
                  'required': ['error_type', 'user_said', 'correct_form', 'explanation']
                }
              }
            ]
          }
        ]
      }
    };
    L.d('Odesílám SETUP s nástroji: ${jsonEncode(setupMessage)}');
    _safeSend(jsonEncode(setupMessage));
  }

  /// Bezpečně odešle textová data do WebSocketu s ošetřením výjimek při rozpadlém spojení.
  void _safeSend(String data) {
    if (_channel == null) return;
    try {
      _channel?.sink.add(data);
    } catch (e) {
      L.w('Chyba při odesílání do WebSocketu: $e');
    }
  }

  int _currentTokenCount = 0;

  /// Vrací aktuální počet spotřebovaných tokenů v relaci.
  int get currentTokenCount => _currentTokenCount;

  /// Odešle raw audio data (PCM 16-bit, 16kHz) zakódovaná do Base64.
  void sendAudioChunk(List<int> pcm16Data) {
    if (_channel == null || _isReconnecting) return;
    
    final base64Audio = base64Encode(pcm16Data);
    final clientContent = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'mimeType': 'audio/pcm;rate=16000',
            'data': base64Audio,
          }
        ]
      }
    };
    _safeSend(jsonEncode(clientContent));
  }

  /// Popostrčí model k vygenerování odpovědi (pokud VAD na serveru nezareagovalo na konec řeči).
  void nudgeModel() {
    if (_channel == null || _isReconnecting) return;
    L.i('Popostrkuji Gemini Live k odpovědi (nudge / turnComplete)...');
    final clientContent = {
      'clientContent': {
        'turnComplete': true
      }
    };
    _safeSend(jsonEncode(clientContent));
  }

  /// Odešle textový vstup od uživatele (např. při psaní na klávesnici v UI).
  void sendText(String text) {
    if (_channel == null) return;
    final clientContent = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [{'text': text}]
          }
        ],
        'turnComplete': true
      }
    };
    _safeSend(jsonEncode(clientContent));
  }

  /// Odešle textový obsah do kontextu relace bez vyvolání odpovědi modelu.
  ///
  /// Slouží pro mid-session updates – tiché injektování instrukcí (např. změna tématu,
  /// obnova kontextu po reconnectu) do aktivního WebSocket spojení.
  /// S [turnComplete] nastaveným na `false` model instrukci absorbuje a čeká na další
  /// audio vstup od uživatele, místo aby okamžitě generoval odpověď.
  void sendClientContent({
    required String role,
    required String text,
    bool turnComplete = false,
  }) {
    if (_channel == null) return;
    final clientContent = {
      'clientContent': {
        'turns': [
          {
            'role': role,
            'parts': [{'text': text}]
          }
        ],
        'turnComplete': turnComplete
      }
    };
    L.i('Odesílám mid-session ClientContent (role: $role, turnComplete: $turnComplete)');
    _safeSend(jsonEncode(clientContent));
  }

  /// Zpracovává a analyzuje všechny příchozí WebSocket zprávy z Gemini serveru.
  void _handleIncomingMessage(dynamic message) {
    try {
      String messageString;
      if (message is String) {
        messageString = message;
      } else if (message is List<int>) {
        messageString = utf8.decode(message);
      } else {
        return;
      }
      
      final data = jsonDecode(messageString);
      
      // Diagnostika: Vypíšeme kořenové klíče zprávy, pokud nejde o běžný přenos audia
      if (data is Map) {
        final keys = data.keys.toList();
        if (!keys.contains('inlineData') && !keys.contains('inline_data')) {
           L.d('WebSocket KEYS: $keys');
        }
      }

      // Detekce systémové chyby ze strany API
      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error['message'] ?? 'Neznámá chyba serveru';
        L.e('Gemini API Error: $msg');
        if (onError != null) onError!(msg);
        return;
      }

      // Podpora pro camelCase (Google standard) i snake_case (který mohou posílat některé proxy)
      final serverContent = data['serverContent'] ?? data['server_content'];
      
      if (serverContent != null) {
        if (serverContent is Map) {
          L.d('serverContent sub-keys: ${serverContent.keys.toList()}');
          
          // Zpracování přerušení (user interruption)
          final interrupted = serverContent['interrupted'];
          if (interrupted == true) {
            L.w('Detekováno přerušení ze strany serveru (uživatel skočil do řeči).');
            _playbackService.interrupt();
            if (onInterrupted != null) {
              onInterrupted!();
            }
          }
        }
        
        // Zpracování Speech-to-Text přepisu řeči uživatele
        final inputTranscription = serverContent['inputTranscription'] ?? serverContent['input_transcription'];
        if (inputTranscription != null) {
          final text = inputTranscription['text'];
          if (text != null) {
            L.i('STT (Uživatel): $text');
            if (onUserTranscriptReceived != null) onUserTranscriptReceived!(text);
          }
        }

        // Zpracování textového přepisu mluveného slova tutora
        final outputTranscription = serverContent['outputTranscription'] ?? serverContent['output_transcription'];
        if (outputTranscription != null) {
          final text = outputTranscription['text'];
          if (text != null) {
            L.d('STT (Tutor kousek): $text');
            final cleanText = _processTextAndDetectStuck(text);
            if (cleanText.isNotEmpty && onTextReceived != null) {
              onTextReceived!(cleanText);
            }
          }
        }

        // Zpracování modelTurn (audio data nebo textové odpovědi)
        final modelTurn = serverContent['modelTurn'] ?? serverContent['model_turn'];
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List?;
          if (parts != null) {
            for (var part in parts) {
              // Ignorujeme myšlenkové pochody modelu (reasoning/thought), pokud jsou posílány
              if (part['thought'] == true) {
                continue;
              }

              final inlineData = part['inlineData'] ?? part['inline_data'];
              if (inlineData != null) {
                final mimeType = inlineData['mimeType'] ?? inlineData['mime_type'] ?? '';
                if (mimeType.startsWith('audio/pcm')) {
                  _consecutiveControlTokens = 0; // Resetujeme pocitadlo pri prijmu realnych audio dat
                  final audioBytes = base64Decode(inlineData['data']);
                  if (onAudioReceived != null) onAudioReceived!(); 
                  // Přehrání audia přes audio playback service
                  _playbackService.playPcmData(audioBytes);
                }
              } 
              else if (part.containsKey('text')) {
                final text = part['text'];
                L.i('Text z modelTurn: $text');
                final cleanText = _processTextAndDetectStuck(text);
                if (cleanText.isNotEmpty && onTextReceived != null) {
                  onTextReceived!(cleanText);
                }
              }
            }
          }
        }
        
        // Detekce konce tahu (model domluvil)
        final turnComplete = serverContent['turnComplete'] ?? serverContent['turn_complete'];
        if (turnComplete == true) {
          L.i('TurnComplete signál přijat.');
          if (onTurnComplete != null) onTurnComplete!();
        }

        // Zpracování signálu generationComplete (model dokončil generování)
        if (serverContent is Map && serverContent.containsKey('generationComplete')) {
          L.d('GenerationComplete signál přijat.');
        }
      }

      // Zpracování usageMetadata (sledování spotřeby tokenů)
      if (data.containsKey('usageMetadata')) {
        final usage = data['usageMetadata'];
        if (usage is Map) {
          final totalTokens = usage['totalTokenCount'] ?? usage['total_token_count'];
          if (totalTokens != null) {
            final count = int.tryParse(totalTokens.toString()) ?? 0;
            if (count > 0) {
              _currentTokenCount = count;
              L.d('UsageMetadata: $count tokenů spotřebováno.');
              if (onTokenCountUpdate != null) onTokenCountUpdate!(count);
            }
          }
        }
      }

      // Zpracování Tool Calls (Function Calling) - může přijít v rootu i pod serverContent
      final toolCall = data['toolCall'] ?? data['tool_call'] ?? (serverContent is Map ? (serverContent['toolCall'] ?? serverContent['tool_call']) : null);
      if (toolCall != null) {
        final functionCalls = toolCall['functionCalls'] ?? toolCall['function_calls'] as List?;
        if (functionCalls != null) {
          for (var call in functionCalls) {
            final name = call['name'];
            final args = call['args'] as Map<String, dynamic>;
            final id = call['id'];

            L.i('Model volá funkci: $name s argumenty: $args');
            if (onToolCall != null) onToolCall!(name, args);

            // Okamžitá automatická odpověď modelu, aby se Live relace nezasekla a mohl pokračovat v řeči
            _sendToolResponse(id, name, {'status': 'ok'});
          }
        }
      }

      // Detekce zrušení rozpracovaného tool callu (např. při přerušení uživatelem)
      if (data.containsKey('toolCallCancellation') || data.containsKey('tool_call_cancellation')) {
        L.w('ToolCall zrušen serverem.');
      }

      // sessionResumptionUpdate: preview model tuto funkci nepodporuje při reconnectu,
      // proto handle ignorujeme (způsoboval 1007 smyčku).
      if (data.containsKey('sessionResumptionUpdate') || data.containsKey('session_resumption_update')) {
        L.d('SessionResumptionUpdate: Přijat (ignorujeme — preview model nepodporuje při reconnectu).');
      }

      // Detekce signálu GoAway (server plánuje brzy ukončit socket)
      // Proaktivní reconnect – okamžitě bezpečně restartujeme spojení bez souběhu
      if (data.containsKey('goAway') || data.containsKey('go_away')) {
        L.w('GoAway signál přijat od serveru. Proaktivně spouštím čistý reconnect...');
        forceReconnect();
      }
    } catch (e, stack) {
      L.e('Chyba zpracování zprávy', e, stack);
    }
  }

  /// Odešle odpověď na vykonaný tool call zpět do WebSocketu.
  void _sendToolResponse(String? id, String name, Map<String, dynamic> response) {
    if (_channel == null) return;
    
    final responseMsg = {
      'toolResponse': {
        'functionResponses': [
          {
            'id': id,
            'name': name,
            'response': response,
          }
        ]
      }
    };
    _safeSend(jsonEncode(responseMsg));
  }

  /// Filtruje ridici tokeny a detekuje pripadne zacykleni modelu.
  String _processTextAndDetectStuck(String text) {
    final controlTokenRegex = RegExp('<' 'ctrl\\d+>');
    final matches = controlTokenRegex.allMatches(text);
    
    if (matches.isNotEmpty) {
      _consecutiveControlTokens += matches.length;
      L.w('Detekovan control token v textu z Gemini. Celkem po sobe: $_consecutiveControlTokens');
      
      if (_consecutiveControlTokens >= 5) {
        L.e('Detekovano zaseknuti Gemini Live API (prilis mnoho control tokenu). Spoustim forceReconnect...');
        _consecutiveControlTokens = 0; // reset
        forceReconnect();
      }
    }
    
    final cleanText = text.replaceAll(controlTokenRegex, '');
    if (cleanText.trim().isNotEmpty) {
      // Pokud mame regulerni netridici text, resetujeme pocitadlo
      _consecutiveControlTokens = 0;
    }
    return cleanText;
  }

  /// Vynutí restartování spojení (zavře socket a okamžitě spustí nové připojení bez souběhu).
  void forceReconnect() {
    L.w('WebSocket: Vynucený reconnect...');
    _isManualDisconnect = false;
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeCurrentChannel();

    if (_lastModelName != null && _lastSystemPrompt != null) {
      connect(
        modelName: _lastModelName!,
        systemPrompt: _lastSystemPrompt!,
        voiceName: _lastVoiceName,
        isReconnect: true,
      );
    }
  }

  /// Ručně odpojí klienta a zruší všechny probíhající operace.
  void disconnect() {
    _isManualDisconnect = true;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeCurrentChannel();
  }
}
