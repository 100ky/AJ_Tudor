import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/providers/config_provider.dart';
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

    test('GeminiModels.tts points to gemini-3.1-flash-tts-preview', () {
      expect(GeminiModels.tts, 'gemini-3.1-flash-tts-preview');
      expect(GeminiModels.ttsFlash2_5, 'gemini-2.5-flash-tts');
      expect(GeminiModels.ttsPro2_5, 'gemini-2.5-pro-preview-tts');
      expect(GeminiModels.getLabel(GeminiModels.tts), contains('Gemini 3.1 Flash TTS'));
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
  });
}

