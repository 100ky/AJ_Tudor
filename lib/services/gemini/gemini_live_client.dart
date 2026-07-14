import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../audio/audio_playback_service.dart';

import 'package:http/http.dart' as http;

class GeminiLiveClient {
  WebSocketChannel? _channel;
  final String _apiKey;
  final AudioPlaybackService _playbackService;
  
  // Callbacky pro UI (např. zobrazení transkripce)
  Function(String)? onTextReceived;
  Function()? onTurnComplete;
  Function(String)? onError;

  GeminiLiveClient(this._apiKey, this._playbackService);

  Future<void> _debugAvailableModels() async {
    try {
      final response = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List;
        final bidiModels = models.where((m) {
          final methods = m['supportedGenerationMethods'] as List?;
          return methods != null && methods.contains('bidiGenerateContent');
        }).map((m) => m['name']).toList();
        
        debugPrint('--- PODPOROVANÉ MODELY PRO LIVE API (BidiGenerateContent) ---');
        debugPrint(bidiModels.toString());
        debugPrint('------------------------------------------------------------');
      } else {
        debugPrint('Nepodařilo se načíst seznam modelů: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Chyba při načítání modelů: $e');
    }
  }

  void connect({required String modelName, required String systemPrompt}) async {
    await _debugAvailableModels();
    
    // Live API aktuálně doporučuje verzi v1beta
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$_apiKey');
    
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      _handleIncomingMessage,
      onError: (error) {
        if (onError != null) onError!('WebSocket chyba: $error');
      },
      onDone: () {
        debugPrint('WebSocket spojení uzavřeno. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
      },
    );

    _sendSetupMessage(modelName, systemPrompt);
  }

  void _sendSetupMessage(String modelName, String systemPrompt) {
    final setupMessage = {
      'setup': {
        // Musíme specifikovat 'models/' prefix, pokud ho uživatel nepředal
        'model': modelName.startsWith('models/') ? modelName : 'models/$modelName',
        'generationConfig': {
          'responseModalities': ['AUDIO'], // Chceme, aby tutor primárně mluvil
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Aoede', // Příjemný přátelský hlas (další možnosti: Puck, Charon, Kore, Fenrir)
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [{'text': systemPrompt}]
        }
      }
    };
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

  void _handleIncomingMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'];
        
        // Zpracování odpovědi modelu
        if (serverContent.containsKey('modelTurn')) {
          final parts = serverContent['modelTurn']['parts'] as List;
          for (var part in parts) {
            // Zvuková data
            if (part.containsKey('inlineData')) {
              final inlineData = part['inlineData'];
              if (inlineData['mimeType'].startsWith('audio/pcm')) {
                final audioBytes = base64Decode(inlineData['data']);
                _playbackService.playPcmData(audioBytes);
              }
            } 
            // Textová transkripce / fallback
            else if (part.containsKey('text')) {
              if (onTextReceived != null) {
                onTextReceived!(part['text']);
              }
            }
          }
        }
        
        // Konec promluvy modelu (Barge-in / Turn Complete)
        if (serverContent.containsKey('turnComplete') && serverContent['turnComplete'] == true) {
          if (onTurnComplete != null) onTurnComplete!();
        }
      }
    } catch (e) {
      if (onError != null) onError!('Chyba zpracování: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
