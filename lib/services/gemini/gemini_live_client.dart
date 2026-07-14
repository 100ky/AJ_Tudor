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
  Function(String)? onUserTranscriptReceived; // Nový: co řekl uživatel
  Function()? onAudioReceived;
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
        'generation_config': {
          'response_modalities': ['AUDIO', 'TEXT'],
          'speech_config': {
            'voice_config': {
              'prebuilt_voice_config': {
                'voice_name': 'Aoede', 
              }
            }
          }
        },
        'system_instruction': {
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
      'realtime_input': {
        'media_chunks': [
          {
            'mime_type': 'audio/pcm;rate=16000',
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
      'client_content': {
        'turns': [
          {
            'role': 'user',
            'parts': [{'text': text}]
          }
        ],
        'turn_complete': true
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

      if (data.containsKey('server_content')) {
        final serverContent = data['server_content'];
        
        // Přepis toho, co řekl uživatel (STT)
        if (serverContent.containsKey('input_transcription')) {
          final text = serverContent['input_transcription']['text'];
          if (onUserTranscriptReceived != null) onUserTranscriptReceived!(text);
        }

        // Přepis toho, co říká model
        if (serverContent.containsKey('output_transcription')) {
          final text = serverContent['output_transcription']['text'];
          if (onTextReceived != null) onTextReceived!(text);
        }

        if (serverContent.containsKey('model_turn')) {
          final parts = serverContent['model_turn']['parts'] as List;
          for (var part in parts) {
            if (part.containsKey('inline_data')) {
              final inlineData = part['inline_data'];
              if (inlineData['mime_type'].startsWith('audio/pcm')) {
                final audioBytes = base64Decode(inlineData['data']);
                if (onAudioReceived != null) onAudioReceived!(); // Informujeme UI
                _playbackService.playPcmData(audioBytes);
              }
            } 
            else if (part.containsKey('text')) {
              if (onTextReceived != null) onTextReceived!(part['text']);
            }
          }
        }
        
        if (serverContent.containsKey('turn_complete') && serverContent['turn_complete'] == true) {
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
