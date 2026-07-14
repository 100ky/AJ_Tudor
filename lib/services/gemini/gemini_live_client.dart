import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../audio/audio_playback_service.dart';

class GeminiLiveClient {
  WebSocketChannel? _channel;
  final String _apiKey;
  final AudioPlaybackService _playbackService;
  
  // Callbacky pro UI
  Function(String)? onTextReceived;
  Function()? onTurnComplete;
  Function(String)? onError;

  GeminiLiveClient(this._apiKey, this._playbackService);

  void connect({required String modelName, required String systemPrompt}) {
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    debugPrint('Připojování k: $uri');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        // Logujeme vše kromě obrovských audio dat, abychom viděli chyby
        if (message is String && !message.contains('inlineData')) {
          debugPrint('WebSocket PŘIJATO: $message');
        }
        _handleIncomingMessage(message);
      },
      onError: (error) {
        debugPrint('WebSocket CHYBA: $error');
        if (onError != null) onError!('WebSocket chyba: $error');
      },
      onDone: () {
        debugPrint('WebSocket spojení UZAVŘENO. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
      },
    );

    _sendSetupMessage(modelName, systemPrompt);
  }

  void _sendSetupMessage(String modelName, String systemPrompt) {
    final setupMessage = {
      'setup': {
        'model': modelName.startsWith('models/') ? modelName : 'models/$modelName',
        'generationConfig': {
          'responseModalities': ['TEXT', 'AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Aoede', 
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [{'text': systemPrompt}]
        }
      }
    };
    debugPrint('Odesílám SETUP: ${jsonEncode(setupMessage)}');
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
      
      // Zpracování chyb přímo od Google serveru
      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error['message'] ?? 'Neznámá chyba serveru';
        if (onError != null) onError!(msg);
        return;
      }

      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'];
        
        if (serverContent.containsKey('modelTurn')) {
          final parts = serverContent['modelTurn']['parts'] as List;
          for (var part in parts) {
            if (part.containsKey('inlineData')) {
              final inlineData = part['inlineData'];
              if (inlineData['mimeType'].startsWith('audio/pcm')) {
                final audioBytes = base64Decode(inlineData['data']);
                _playbackService.playPcmData(audioBytes);
              }
            } 
            else if (part.containsKey('text')) {
              if (onTextReceived != null) onTextReceived!(part['text']);
            }
          }
        }
        
        if (serverContent.containsKey('turnComplete') && serverContent['turnComplete'] == true) {
          if (onTurnComplete != null) onTurnComplete!();
        }
      }
    } catch (e) {
      debugPrint('Chyba zpracování zprávy: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
