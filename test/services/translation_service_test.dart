import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/providers/config_provider.dart';
import 'package:aj_tudor/services/gemini/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordTranslationService Tests', () {
    late ProviderContainer container;
    late WordTranslationService service;

    setUp(() async {
      WordTranslationService.resetState();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      service = container.read(wordTranslationServiceProvider);
    });

    tearDown(() {
      WordTranslationService.resetState();
      container.dispose();
    });

    test('cleanWord strips quotes and punctuation correctly', () {
      expect(WordTranslationService.cleanWord('  "hello",  '), 'hello');
      expect(WordTranslationService.cleanWord('„world!“'), 'world');
      expect(WordTranslationService.cleanWord('(apple)?'), 'apple');
      expect(WordTranslationService.cleanWord('keep in mind'), 'keep in mind');
    });

    test('translate returns empty string for empty input', () async {
      final result = await service.translate(text: '   ');
      expect(result, '');
    });

    test('translate reads pre-existing disk cache and serves translation immediately', () async {
      final tempDir = Directory.systemTemp.createTempSync('trans_test_');
      final tempFile = File('${tempDir.path}/test_translations.json');
      await tempFile.writeAsString(jsonEncode({
        'perseverance__': 'vytrvalost',
        'apple__i ate an apple.': 'jablko',
      }));

      WordTranslationService.diskCacheFileOverride = tempFile;

      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      expect(WordTranslationService.cachedCount, 0);

      // Překlad bez kontextu
      final result1 = await service.translate(text: 'perseverance');
      expect(result1, 'vytrvalost');
      expect(WordTranslationService.cachedCount, 2);

      // Překlad s kontextem
      final result2 = await service.translate(text: 'apple', contextSentence: 'I ate an apple.');
      expect(result2, 'jablko');
    });

    test('clearCache clears memory and removes disk cache file', () async {
      final tempDir = Directory.systemTemp.createTempSync('trans_clear_');
      final tempFile = File('${tempDir.path}/cache.json');
      await tempFile.writeAsString(jsonEncode({'hello__': 'ahoj'}));

      WordTranslationService.diskCacheFileOverride = tempFile;

      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Načteme do paměti
      final res = await service.translate(text: 'hello');
      expect(res, 'ahoj');
      expect(WordTranslationService.cachedCount, 1);
      expect(await tempFile.exists(), true);

      // Smažeme cache
      await WordTranslationService.clearCache();
      expect(WordTranslationService.cachedCount, 0);
      expect(await tempFile.exists(), false);
    });
  });
}

