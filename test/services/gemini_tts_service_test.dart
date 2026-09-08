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
  });
}

