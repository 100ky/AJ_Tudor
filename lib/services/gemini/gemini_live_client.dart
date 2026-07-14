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
    // Vracíme se k v1alpha a camelCase, což je pro tento preview model obvyklejší
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    debugPrint('Připojování k: $uri');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        if (message is String && !message.contains('inlineData') && !message.contains('inline_data')) {
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

    // Krátká prodleva pro stabilitu
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_channel != null) {
        _sendSetupMessage(modelName, systemPrompt);
      }
    });
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
      
      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error['message'] ?? 'Neznámá chyba serveru';
        if (onError != null) onError!(msg);
        return;
      }

      // Podpora pro camelCase (Google standard) i snake_case (některé proxy/SDK)
      final serverContent = data['serverContent'] ?? data['server_content'];
      
      if (serverContent != null) {
        // Přepis toho, co řekl uživatel (STT)
        final inputTranscription = serverContent['inputTranscription'] ?? serverContent['input_transcription'];
        if (inputTranscription != null) {
          final text = inputTranscription['text'];
          if (onUserTranscriptReceived != null) onUserTranscriptReceived!(text);
        }

        // Přepis toho, co říká model
        final outputTranscription = serverContent['outputTranscription'] ?? serverContent['output_transcription'];
        if (outputTranscription != null) {
          final text = outputTranscription['text'];
          if (onTextReceived != null) onTextReceived!(text);
        }

        final modelTurn = serverContent['modelTurn'] ?? serverContent['model_turn'];
        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List;
          for (var part in parts) {
            final inlineData = part['inlineData'] ?? part['inline_data'];
            if (inlineData != null) {
              if (inlineData['mimeType'].startsWith('audio/pcm') || inlineData['mime_type'].startsWith('audio/pcm')) {
                final audioBytes = base64Decode(inlineData['data']);
                if (onAudioReceived != null) onAudioReceived!(); 
                _playbackService.playPcmData(audioBytes);
              }
            } 
            else if (part.containsKey('text')) {
              if (onTextReceived != null) onTextReceived!(part['text']);
            }
          }
        }
        
        final turnComplete = serverContent['turnComplete'] ?? serverContent['turn_complete'];
        if (turnComplete == true) {
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
