import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/utils/logger.dart';
import '../audio/audio_playback_service.dart';

class GeminiLiveClient {
  WebSocketChannel? _channel;
  final String _apiKey;
  final AudioPlaybackService _playbackService;
  
  // Reconnect logika
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  bool _isManualDisconnect = false;
  String? _lastModelName;
  String? _lastSystemPrompt;

  bool get isConnected => _channel != null && _reconnectAttempts == 0;

  // Callbacky pro UI
  Function(String)? onTextReceived;
  Function(String)? onUserTranscriptReceived;
  Function()? onAudioReceived;
  Function()? onTurnComplete;
  Function(String)? onError;
  Function(bool)? onConnectionStatusChanged;
  Function(String name, Map<String, dynamic> args)? onToolCall;

  GeminiLiveClient(this._apiKey, this._playbackService);

  void connect({required String modelName, required String systemPrompt}) {
    _isManualDisconnect = false;
    _lastModelName = modelName;
    _lastSystemPrompt = systemPrompt;
    
    // Čištění starého spojení, pokud existuje
    _channel?.sink.close();
    
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    debugPrint('Připojování k: $uri');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0; // Resetujeme pokusy při úspěšném příjmu dat
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(true);

        if (message is String && !message.contains('inlineData') && !message.contains('inline_data')) {
          debugPrint('WebSocket PŘIJATO: $message');
        }
        _handleIncomingMessage(message);
      },
      onError: (error) {
        debugPrint('WebSocket CHYBA: $error');
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(false);
        _handleError(error.toString());
      },
      onDone: () {
        debugPrint('WebSocket spojení UZAVŘENO. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
        if (onConnectionStatusChanged != null) onConnectionStatusChanged!(false);
        
        if (!_isManualDisconnect) {
          _attemptReconnect();
        }
      },
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_channel != null) {
        _sendSetupMessage(modelName, systemPrompt);
      }
    });
  }

  void _attemptReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts && _lastModelName != null && _lastSystemPrompt != null) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2); // Exponenciální backoff
      debugPrint('Pokus o znovupřipojení č. $_reconnectAttempts za ${delay.inSeconds}s...');
      
      Future.delayed(delay, () {
        if (!_isManualDisconnect) {
          connect(modelName: _lastModelName!, systemPrompt: _lastSystemPrompt!);
        }
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (onError != null) onError!('Nepodařilo se obnovit spojení po $_maxReconnectAttempts pokusech.');
    }
  }

  void _handleError(String errorMsg) {
    if (errorMsg.contains('429')) {
      if (onError != null) onError!('Překročena kvóta API (Rate limit). Zkuste to za chvíli.');
    } else if (errorMsg.contains('1008')) {
      debugPrint('GoAway detekován, zkouším reconnect...');
      _attemptReconnect();
    } else {
      L.e('WebSocket CHYBA: $errorMsg');
      if (onError != null) onError!('Chyba spojení: $errorMsg');
    }
  }

  void _sendSetupMessage(String modelName, String systemPrompt) {
    final setupMessage = {
      'setup': {
        'model': modelName.startsWith('models/') ? modelName : 'models/$modelName',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Puck', 
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [{'text': systemPrompt}]
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
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
    debugPrint('Odesílám SETUP s nástroji: ${jsonEncode(setupMessage)}');
    _channel?.sink.add(jsonEncode(setupMessage));
  }

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
      
      // DIAGNOSTIKA: Vypíšeme klíče v rootu zprávy
      if (data is Map) {
        final keys = data.keys.toList();
        if (!keys.contains('inlineData') && !keys.contains('inline_data')) {
           L.d('WebSocket KEYS: $keys');
        }
      }

      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error['message'] ?? 'Neznámá chyba serveru';
        L.e('Gemini API Error: $msg');
        if (onError != null) onError!(msg);
        return;
      }

      // Podpora pro camelCase (Google standard) i snake_case (některé proxy/SDK)
      final serverContent = data['serverContent'] ?? data['server_content'];
      
      if (serverContent != null) {
        if (serverContent is Map) {
          L.d('serverContent sub-keys: ${serverContent.keys.toList()}');
        }
        
        // Přepis toho, co řekl uživatel (STT)
        final inputTranscription = serverContent['inputTranscription'] ?? serverContent['input_transcription'];
        if (inputTranscription != null) {
          final text = inputTranscription['text'];
          if (text != null) {
            L.i('STT (Uživatel): $text');
            if (onUserTranscriptReceived != null) onUserTranscriptReceived!(text);
          }
        }

        // Přepis toho, co říká model (STT) - obvykle chodí průběžně
        final outputTranscription = serverContent['outputTranscription'] ?? serverContent['output_transcription'];
        if (outputTranscription != null) {
          final text = outputTranscription['text'];
          if (text != null) {
            L.d('STT (Tutor kousek): $text');
            if (onTextReceived != null) onTextReceived!(text);
          }
        }

        final modelTurn = serverContent['modelTurn'] ?? serverContent['model_turn'];
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List?;
          if (parts != null) {
            for (var part in parts) {
              // Ignorujeme myšlenkové pochody modelu (reasoning/thought)
              if (part['thought'] == true) {
                continue;
              }

              final inlineData = part['inlineData'] ?? part['inline_data'];
              if (inlineData != null) {
                if (inlineData['mimeType'].startsWith('audio/pcm') || inlineData['mime_type'].startsWith('audio/pcm')) {
                  final audioBytes = base64Decode(inlineData['data']);
                  if (onAudioReceived != null) onAudioReceived!(); 
                  _playbackService.playPcmData(audioBytes);
                }
              } 
              else if (part.containsKey('text')) {
                final text = part['text'];
                L.i('Text z modelTurn: $text');
                if (onTextReceived != null) onTextReceived!(text);
              }
            }
          }
        }
        
        final turnComplete = serverContent['turnComplete'] ?? serverContent['turn_complete'];
        if (turnComplete == true) {
          L.i('TurnComplete signál přijat.');
          if (onTurnComplete != null) onTurnComplete!();
        }
      }

      // Zpracování Tool Calls (Function Calling) v rootu i v serverContent
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

            // Okamžitá odpověď modelu, aby mohl pokračovat
            _sendToolResponse(id, name, {'status': 'ok'});
          }
        }
      }

      // Detekce zrušení tool call (např. při přerušení)
      if (data.containsKey('toolCallCancellation') || data.containsKey('tool_call_cancellation')) {
        L.w('ToolCall zrušen serverem.');
      }
    } catch (e) {
      debugPrint('Chyba zpracování zprávy: $e');
    }
  }

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

  void forceReconnect() {
    debugPrint('WebSocket: Vynucený reconnect...');
    _isManualDisconnect = false;
    _channel?.sink.close();
    // Tím se vyvolá onDone a následný _attemptReconnect
  }

  void disconnect() {
    _isManualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
  }
}
