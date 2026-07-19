import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/utils/logger.dart';
import '../audio/audio_playback_service.dart';

/// Klient pro obousměrnou real-time komunikaci s Gemini Live API přes WebSocket.
/// 
/// Zajišťuje odesílání hlasových (PCM 16-bit) a textových dat do Gemini a asynchronní
/// zpracování odpovědí (audio streamování zpět, transkripce řeči studenta i AI, tool calling atd.).
/// Obsahuje automatickou logiku znovupřipojení s exponenciálním backoffem.
class GeminiLiveClient {
  /// Aktivní WebSocket kanál pro bidi-streamování.
  WebSocketChannel? _channel;

  /// API klíč pro autentizaci vůči Gemini.
  final String _apiKey;

  /// Služba pro přehrávání přijatých audio dat.
  final AudioPlaybackService _playbackService;
  
  // Reconnect logika a stavové proměnné
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  bool _isManualDisconnect = false;
  String? _lastModelName;
  String? _lastSystemPrompt;
  String _lastVoiceName = 'Puck';
  String? _lastResumptionHandle;

  // Pocitadlo po sobe jdoucich ridicich tokenu (ochrana pred zaseknutim v loopu)
  int _consecutiveControlTokens = 0;

  /// Vrací [bool] vyjadřující, zda je klient momentálně připojen a nemá aktivní pokusy o reconnect.
  bool get isConnected => _channel != null && _reconnectAttempts == 0;

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

  /// Vyvoláno, když uživatel přeruší mluvení modelu (interruption).
  Function()? onInterrupted;

  /// Konstruktor vyžadující API klíč a instanci služby přehrávání zvuku.
  GeminiLiveClient(this._apiKey, this._playbackService);

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
    
    // Pokud se nejedná o reconnect, zahazujeme starý resumption handle (nové sezení).
    if (!isReconnect) {
      _lastResumptionHandle = null;
    }
    
    // Čištění starého spojení, pokud existuje.
    _channel?.sink.close();
    
    // Sestavení URI pro bidi-generate WebSocket.
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    L.i('Připojování k: $uri');
    _channel = WebSocketChannel.connect(uri);

    // Naslouchání na příchozím streamu WebSocketu.
    _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0; // Resetujeme pokusy při úspěšném příjmu jakýchkoliv dat.
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
        L.w('WebSocket spojení UZAVŘENO. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(false);
        
        // Pokud nebylo spojení zavřeno ručně uživatelem, pokusíme se o reconnect.
        if (!_isManualDisconnect) {
          _attemptReconnect();
        }
      },
    );

    // Odeslání konfigurační (SETUP) zprávy s krátkou prodlevou po navázání socketu.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_channel != null) {
        _sendSetupMessage(modelName, systemPrompt, voiceName);
      }
    });
  }

  /// Pokusí se o automatické znovupřipojení s exponenciálním backoffem.
  void _attemptReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts && _lastModelName != null && _lastSystemPrompt != null) {
      _reconnectAttempts++;
      // Exponenciální prodleva mezi pokusy (2s, 4s, 6s, 8s, 10s).
      final delay = Duration(seconds: _reconnectAttempts * 2);
      L.i('Pokus o znovupřipojení č. $_reconnectAttempts za ${delay.inSeconds}s...');
      
      Future.delayed(delay, () {
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
      if (onError != null) onError!('Nepodařilo se obnovit spojení po $_maxReconnectAttempts pokusech.');
    }
  }

  /// Vyhodnocuje chybové kódy a zprávy z WebSocketu.
  void _handleError(String errorMsg) {
    if (errorMsg.contains('429')) {
      if (onError != null) onError!('Překročena kvóta API (Rate limit). Zkuste to za chvíli.');
    } else if (errorMsg.contains('1008')) {
      L.w('GoAway detekován (kód 1008), zkouším reconnect...');
      _attemptReconnect();
    } else {
      L.e('WebSocket CHYBA: $errorMsg');
      if (onError != null) onError!('Chyba spojení: $errorMsg');
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
          }
        },
        'systemInstruction': {
          'parts': [{'text': systemPrompt}]
        },
        // Povolíme transkripci jak pro vstup, tak pro výstup
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        // Pokud máme resumption handle z předchozího odpojení, pokusíme se navázat na kontext
        if (_lastResumptionHandle != null)
          'sessionResumptionConfig': {
            'handle': _lastResumptionHandle,
          },
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
    _channel?.sink.add(jsonEncode(setupMessage));
  }

  /// Odešle raw audio data (PCM 16-bit, 16kHz) zakódovaná do Base64.
  void sendAudioChunk(List<int> pcm16Data) {
    if (_channel == null) return;
    
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
    _channel?.sink.add(jsonEncode(clientContent));
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
    _channel?.sink.add(jsonEncode(clientContent));
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

      // Zpracování aktualizace Session Resumption (ukládání handle pro případný reconnect)
      if (data.containsKey('sessionResumptionUpdate') || data.containsKey('session_resumption_update')) {
        final update = data['sessionResumptionUpdate'] ?? data['session_resumption_update'];
        if (update != null && update is Map) {
          final newHandle = update['newHandle'] ?? update['new_handle'];
          if (newHandle != null && newHandle is String) {
            L.i('SessionResumptionUpdate: Obdržen nový resumption handle: $newHandle');
            _lastResumptionHandle = newHandle;
          }
        }
      }

      // Detekce signálu GoAway (server plánuje brzy ukončit socket)
      if (data.containsKey('goAway') || data.containsKey('go_away')) {
        L.w('GoAway signál přijat od serveru. Spojení bude brzy ukončeno.');
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
    _channel?.sink.add(jsonEncode(responseMsg));
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

  /// Vynutí restartování spojení (zavře socket a spustí reconnect mechanismus).
  void forceReconnect() {
    L.w('WebSocket: Vynucený reconnect...');
    _isManualDisconnect = false;
    _channel?.sink.close();
  }

  /// Ručně odpojí klienta a zruší všechny probíhající operace.
  void disconnect() {
    _isManualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
  }
}
