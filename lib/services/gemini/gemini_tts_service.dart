import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../providers/audio_provider.dart';
import '../../providers/config_provider.dart';


/// Služba pro převod textu na řeč (Text-to-Speech) pomocí modelu Gemini TTS.
/// 
/// Umožňuje přehrát vzorovou britskou/americkou výslovnost libovolného slovíčka,
/// fráze nebo věty v chatu a na kartičkách (Flashcards).
class GeminiTtsService {
  final Ref _ref;
  final Dio _dio;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  GeminiTtsService(this._ref)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ));

  /// Vygeneruje a přehraje výslovnost zadaného textu.
  /// 
  /// [text] je anglický text k vyslovení.
  /// [instruction] volitelná instrukce pro intonaci či přízvuk (např. 'Speak slowly and emphasize past tense.').
  Future<bool> speak(String text, {String? instruction}) async {
    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      L.w('Gemini TTS: Chybí API klíč, nelze přehrát výslovnost.');
      return false;
    }

    final voiceName = _ref.read(voiceProvider);
    final audioPlayback = _ref.read(audioPlaybackServiceProvider);

    final cleanText = _sanitizeTextForSpeech(text);
    if (cleanText.isEmpty) return false;

    try {
      L.i('Gemini TTS: Generuji výslovnost pro text: "$cleanText" (hlas: $voiceName)...');

      final promptText = instruction != null && instruction.isNotEmpty
          ? '$instruction\n\nText: "$cleanText"'
          : 'Pronounce clearly with standard native accent: "$cleanText"';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': promptText}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceName,
              }
            }
          }
        }
      };

      // Nativní audio modely s podporou responseModalities: ['AUDIO']
      final modelsToTry = [
        GeminiModels.tts,
        GeminiModels.flash2_5,
        'gemini-2.0-flash',
        'gemini-2.0-flash-exp',
        'gemini-2.0-flash-preview',
        GeminiModels.flash3_8,
        GeminiModels.flash3_7,
      ];

      for (var model in modelsToTry) {
        try {
          final url = '$_baseUrl/$model:generateContent?key=$apiKey';
          final response = await _dio.post(
            url,
            data: requestBody,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode == 200 && response.data != null) {
            final candidates = response.data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                for (var part in parts) {
                  final inlineData = part['inlineData'];
                  if (inlineData != null && inlineData['data'] != null) {
                    final String base64Data = inlineData['data'];
                    final bytes = base64Decode(base64Data);

                    // Přehrání surových PCM/audio bytů
                    await audioPlayback.playPcmData(bytes);
                    L.i('Gemini TTS: Výslovnost úspěšně přehrána (${bytes.length} B).');
                    return true;
                  }
                }
              }
            }
          }
        } catch (e) {
          L.w('Gemini TTS model $model selhal, zkouším další fallback: $e');
        }
      }

      L.e('Gemini TTS: Žádný model nevrátil platné audio.');
      return false;
    } catch (e, stack) {
      L.e('Gemini TTS: Neočekávaná chyba při syntéze řeči', e, stack);
      return false;
    }
  }

  /// Zastaví aktuálně probíhající přehrávání výslovnosti.
  Future<void> stop() async {
    final audioPlayback = _ref.read(audioPlaybackServiceProvider);
    await audioPlayback.stop();
  }

  /// Očistí text od markdown značek (hvězdičky, mřížky, odrážky),
  /// aby syntetizér četl přirozeně a nevyslovoval formátovací značky.
  String _sanitizeTextForSpeech(String rawText) {
    return rawText
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[#_~]'), '')
        .trim();
  }
}

/// Globální Riverpod provider pro [GeminiTtsService].
final geminiTtsServiceProvider = Provider<GeminiTtsService>((ref) {
  return GeminiTtsService(ref);
});
