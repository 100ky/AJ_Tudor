import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/gemini_models.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';
import '../../core/error/error_handling.dart';
import '../../core/config/config_providers.dart';
import '../../data/data_providers.dart';
import '../prompt/task_prompts.dart';
import 'gemini_rest_core.dart';

/// Výsledek překladu slova/fráze včetně případně vytvořené kartičky.
class TranslationResult {
  final String originalText;
  final String translatedText;
  final int? flashcardId;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    this.flashcardId,
  });
}

/// Služba pro bleskový kontextový překlad slov a frází s automatickým zařazením do Smart Flashcards.
class WordTranslationService {
  final Ref _ref;
  final GeminiRestCore _api;

  /// Bleskové modely optimalizované pro rychlý překlad slov a frází bez prodlev
  static const List<String> _fastModels = [
    GeminiModels.flashLite3_5, // gemini-3.5-flash-lite – ultra rychlý a lehký
    GeminiModels.flashLite3_1, // gemini-3.1-flash-lite – bleskový lehký model
    GeminiModels.flash3_5,     // gemini-3.5-flash
    GeminiModels.flash3_6,     // gemini-3.6-flash
    GeminiModels.flash3_8,     // gemini-3.8-flash (fallback)
  ];

  /// Dočasná paměťová mezipaměť (anglický výraz + kontext -> český překlad)
  static final Map<String, String> _translationCache = {};

  /// Dočasný cooldown pro přetížené modely (503/429/timeout)
  static final ModelCooldownTracker _cooldowns = ModelCooldownTracker();

  /// Příznak, zda již byla načtena disková mezipaměť
  static bool _diskCacheLoaded = false;

  /// Volitelné přepsání souboru mezipaměti (pro testy)
  static File? diskCacheFileOverride;

  WordTranslationService(this._ref)
      : _api = GeminiRestCore(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 4),
        );

  /// Počet položek v paměťové mezipaměti překladů.
  static int get cachedCount => _translationCache.length;

  /// Resetuje mezipaměť (pro testování a debug).
  static void resetState() {
    _translationCache.clear();
    _cooldowns.clear();
    _diskCacheLoaded = false;
    diskCacheFileOverride = null;
  }

  /// Získá referenci na soubor diskové mezipaměti.
  static Future<File?> _getCacheFile() async {
    if (diskCacheFileOverride != null) return diskCacheFileOverride;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return File(p.join(appDir.path, 'aj_tudor_translations_cache.json'));
    } catch (e) {
      L.w('WordTranslationService: Nepodařilo se získat soubor pro diskovou mezipaměť: $e');
      return null;
    }
  }

  /// Načte data z diskové mezipaměti do paměti (pokud ještě nebyla načtena).
  static Future<void> _ensureDiskCacheLoaded() async {
    if (_diskCacheLoaded) return;
    _diskCacheLoaded = true;
    try {
      final file = await _getCacheFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        for (final entry in jsonMap.entries) {
          if (entry.value is String) {
            _translationCache[entry.key] = entry.value as String;
          }
        }
        L.i('WordTranslationService: Načteno ${_translationCache.length} překladů z diskové mezipaměti.');
      }
    } catch (e) {
      L.w('WordTranslationService: Chyba při načítání diskové mezipaměti překladů: $e');
    }
  }

  /// Uloží celou mezipaměť překladů na disk.
  static Future<void> _saveDiskCache() async {
    try {
      final file = await _getCacheFile();
      if (file == null) return;
      final jsonString = jsonEncode(_translationCache);
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      L.w('WordTranslationService: Chyba při ukládání překladů na disk: $e');
    }
  }

  /// Vymaže paměťovou i diskovou mezipaměť překladů.
  static Future<void> clearCache() async {
    _translationCache.clear();
    _diskCacheLoaded = false;
    try {
      final file = await _getCacheFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      L.w('WordTranslationService: Chyba při mazání souboru mezipaměti překladů: $e');
    }
  }

  /// Vyčistí interpunkci a bílé znaky ze začátku a konce slova/fráze
  static String cleanWord(String input) {
    return input
        .replaceAll(RegExp(r"^[\s.,!?;:()„“”'\x22]+|[\s.,!?;:()„“”'\x22]+$"), '')
        .trim();
  }

  /// Přeloží slovo nebo frázi do češtiny v kontextu celé věty.
  Future<String> translate({
    required String text,
    String? contextSentence,
  }) async {
    final cleaned = cleanWord(text);
    if (cleaned.isEmpty) return '';

    await _ensureDiskCacheLoaded();

    final cacheKey = '${cleaned.toLowerCase()}__${contextSentence?.trim().toLowerCase() ?? ''}';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    final apiKey = _ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      return 'Chybí API klíč pro překladač';
    }

    final stopwatch = Stopwatch()..start();

    // Stručný, lehký prompt (bez mohutného systémového promptu tutora)
    final requestBody = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {'text': TaskPrompts.wordTranslationSystem}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': TaskPrompts.wordTranslationRequest(
                word: cleaned,
                contextSentence: contextSentence,
              )
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
      },
    };

    for (final modelName in _cooldowns.order(_fastModels)) {
      try {
        final data = await _api.generateContent(
          apiKey: apiKey,
          model: modelName,
          body: requestBody,
        );

        final rawText = GeminiRestCore.extractText(data) ?? '';
        final cleanTranslation = rawText
            .replaceAll('"', '')
            .replaceAll('„', '')
            .replaceAll('“', '')
            .replaceAll('\n', ' ')
            .trim();

        if (cleanTranslation.isNotEmpty && !cleanTranslation.startsWith('❌')) {
          _cooldowns.markSuccess(modelName);
          _translationCache[cacheKey] = cleanTranslation;
          unawaited(_saveDiskCache());
          stopwatch.stop();
          L.i('Bleskový překlad "$cleaned" -> "$cleanTranslation" ($modelName, ${stopwatch.elapsedMilliseconds}ms)');
          return cleanTranslation;
        }
      } on DioException catch (e) {
        if (classifyGeminiError(e) == GeminiErrorKind.overloaded) {
          _cooldowns.markOverloaded(modelName, const Duration(minutes: 2));
          L.w('Model $modelName přetížen/timeout (${e.response?.statusCode ?? 0}). Dávám na 2min cooldown a zkouším další...');
        } else {
          L.w('Model $modelName selhal při překladu ($e), zkouším další...');
        }
      } catch (e) {
        L.w('Model $modelName selhal při překladu ($e), zkouším další...');
      }
    }

    return 'Překlad se nezdařil';
  }

  /// Uloží výraz do stávajícího systému Flashcards a aktualizuje slovní zásobu v profilu studenta.
  Future<Result<int>> saveToFlashcards({
    required String englishText,
    required String czechText,
    String? contextSentence,
  }) async {
    final cleanedEn = cleanWord(englishText);
    final cleanedCs = czechText.trim();

    if (cleanedEn.isEmpty || cleanedCs.isEmpty) {
      return Result.failure(DatabaseFailure('Prázdné slovo nebo překlad.'));
    }

    try {
      final flashcardRepo = _ref.read(flashcardRepositoryProvider);
      final profileRepo = _ref.read(profileRepositoryProvider);

      final explanation = (contextSentence != null && contextSentence.trim().isNotEmpty)
          ? 'Z věty tutora: "${contextSentence.trim()}"'
          : 'Slovíčko z konverzace s tutorem';

      final cardResult = await flashcardRepo.addFlashcard(
        frontText: cleanedCs,
        backText: cleanedEn,
        explanation: explanation,
        errorType: 'vocabulary',
        sourceSentence: contextSentence,
      );

      if (cardResult.isSuccess) {
        // Aktualizujeme slovní zásobu v profilu studenta, aby tutor věděl, co se student učí
        try {
          await profileRepo.updateUserVocabulary([cleanedEn]);
        } catch (_) {}
      }

      return cardResult;
    } catch (e, stack) {
      L.e('Chyba při ukládání do flashcards', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se uložit do kartiček.'));
    }
  }

  /// Odstraní dříve vytvořenou kartičku (Undo akce).
  Future<Result<void>> removeFromFlashcards(int flashcardId) async {
    try {
      return await _ref.read(flashcardRepositoryProvider).deleteFlashcard(flashcardId);
    } catch (e, stack) {
      L.e('Chyba při mazání kartičky #$flashcardId', e, stack);
      return Result.failure(DatabaseFailure('Nepodařilo se odebrat kartičku.'));
    }
  }
}

/// Provider pro přístup k překladové službě
final wordTranslationServiceProvider = Provider<WordTranslationService>((ref) {
  return WordTranslationService(ref);
});
