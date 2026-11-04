import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/services/audio/pcm_wav.dart';
import 'package:aj_tudor/services/gemini/gemini_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiTtsService Tests', () {
    late ProviderContainer container;
    late GeminiTtsService service;

    setUp(() async {
      GeminiTtsService.resetState();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      service = container.read(geminiTtsServiceProvider);
    });

    tearDown(() {
      GeminiTtsService.resetState();
      container.dispose();
    });

    test('GeminiModels.tts points to updated TTS models', () {
      expect(GeminiModels.tts, 'gemini-3.8-flash-tts');
      expect(GeminiModels.ttsLite, 'gemini-3.8-flash-lite-tts');
      expect(GeminiModels.getLabel(GeminiModels.tts), contains('Gemini 3.8 Flash TTS'));
    });

    group('audio from the model response', () {
      Map<String, dynamic> response(List<int> audio) => {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {'mimeType': 'audio/wav', 'data': base64Encode(audio)}
                    }
                  ]
                }
              }
            ]
          };

      test('a WAV response plays only its sound, not the header or the C2PA metadata', () {
        // gemini-3.8-flash-tts vrací celý WAV a za zvukem blok C2PA, který zněl na konci jako šum
        final pcm = List<int>.generate(480, (i) => i % 251);
        final c2pa = [...'C2PA'.codeUnits, 6, 0, 0, 0, 1, 2, 3, 4, 5, 6];
        final wav = [...pcm16ToWav(pcm, sampleRate: 24000), ...c2pa];

        expect(GeminiTtsService.extractAudio(response(wav)), pcm);
      });

      test('raw PCM from the older models is played as it is', () {
        final pcm = List<int>.generate(480, (i) => i % 7);
        expect(GeminiTtsService.extractAudio(response(pcm)), pcm);
      });
    });

    test('sanitizeTextForSpeech strips markdown formatting correctly', () {
      expect(
        GeminiTtsService.sanitizeTextForSpeech('**stamina**'),
        'stamina',
      );
      expect(
        GeminiTtsService.sanitizeTextForSpeech('*perseverance*'),
        'perseverance',
      );
      expect(
        GeminiTtsService.sanitizeTextForSpeech('`code block`'),
        'code block',
      );
      expect(
        GeminiTtsService.sanitizeTextForSpeech('# Heading\n- Item 1\n* Item 2'),
        'Heading\nItem 1\nItem 2',
      );
      expect(
        GeminiTtsService.sanitizeTextForSpeech('[Click here](https://example.com)'),
        'Click here',
      );
    });

    test('speak returns false if API key is missing', () async {
      final result = await service.speak('hello');
      expect(result, false);
    });

    test('resetState clears cached audio count and preferred working model', () {
      expect(GeminiTtsService.cachedAudioCount, 0);
      expect(GeminiTtsService.preferredWorkingModel, null);
    });

    test('disk cache directory override and clearDiskCache works', () async {
      final tempDir = Directory.systemTemp.createTempSync('tts_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      GeminiTtsService.diskCacheDirOverride = tempDir;

      // Vytvoříme testovací soubor v cache složce
      final dummyFile = File('${tempDir.path}/test.pcm');
      await dummyFile.writeAsBytes([0, 1, 2, 3]);
      expect(await dummyFile.exists(), true);

      await GeminiTtsService.clearDiskCache();
      expect(await dummyFile.exists(), false);
    });

    test('speak plays from disk cache if present and populates memory cache', () async {
      final tempDir = Directory.systemTemp.createTempSync('tts_cache_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      GeminiTtsService.diskCacheDirOverride = tempDir;

      // Nastavíme testovací API klíč
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', 'test_key_123');
      final containerWithKey = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(containerWithKey.dispose);
      final tts = containerWithKey.read(geminiTtsServiceProvider);

      // Připravíme soubor na disku s odpovídajícím názvem podle cacheKey: "hello-Puck"
      const cleanText = 'hello';
      final voiceName = containerWithKey.read(voiceProvider);
      final cacheKey = '$cleanText-$voiceName';
      final sanitized = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final prefix = sanitized.length > 30 ? sanitized.substring(0, 30) : sanitized;
      final hash = cacheKey.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
      final fileName = '${prefix}_$hash.pcm';

      final cachedPcmFile = File('${tempDir.path}/$fileName');
      // Zapíšeme 48 bytů pro 1ms zvuku
      await cachedPcmFile.writeAsBytes(List.filled(48, 0));

      expect(GeminiTtsService.cachedAudioCount, 0);

      final success = await tts.speak(cleanText);
      expect(success, true);
      // Mělo by být načteno z disku a vloženo do paměťové mezipaměti
      expect(GeminiTtsService.cachedAudioCount, 1);
    });

    test('a cached WAV recording from before the fix is deleted instead of played', () async {
      // Takové nahrávky vytvořil gemini-3.8-flash-tts, který předčítal i pokyny k textu
      final tempDir = Directory.systemTemp.createTempSync('tts_cache_wav_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      GeminiTtsService.diskCacheDirOverride = tempDir;

      final cacheKey = 'intrigued-${container.read(voiceProvider)}';
      final hash = cacheKey.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
      final cached = File('${tempDir.path}/${cacheKey}_$hash.pcm');
      await cached.writeAsBytes(pcm16ToWav(List.filled(48, 0), sampleRate: 24000));

      // Bez API klíče se nová nahrávka nevytvoří, stará se ale nepřehraje
      expect(await service.speak('intrigued'), false);
      expect(await cached.exists(), false);
      expect(GeminiTtsService.cachedAudioCount, 0);
    });
  });
}

