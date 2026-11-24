import 'dart:convert';

import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/data/repositories/topic_history_repository.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';
import 'package:aj_tudor/services/topics/topic_history_backfill.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGemini extends Mock implements GeminiBatchClient {}

class _FakeApiKeyNotifier extends ApiKeyNotifier {
  @override
  String? build() => 'test-key';
}

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late _MockGemini gemini;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sessions = SessionRepository(db);
    gemini = _MockGemini();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      geminiTopicBackfillClientProvider.overrideWithValue(gemini),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> lesson(String summary) async {
    final id = (await sessions.startNewSession()).getOrThrow();
    await sessions.updateSessionAnalysis(sessionId: id, topicSummary: summary, fluencyScore: 0.6, totalErrors: 0);
    return id;
  }

  void answer(Map<String, Object?> json) {
    when(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'))).thenAnswer((_) async => jsonEncode(json));
  }

  test('older lessons are sorted into areas once, from their summaries', () async {
    final work = await lesson('Práce v Power Platform a Project Water');
    final hike = await lesson('Výlet do Toulovcových Maštalí');
    answer({
      'sessions': [
        {
          'sessionId': work,
          'topics': [
            {'area': 'prace', 'title': 'Project Water'},
            {'area': 'technologie', 'title': 'Power Platform'},
          ],
        },
        {
          'sessionId': hike,
          'topics': [
            {'area': 'priroda', 'title': 'Výlet do Toulovcových Maštalí'},
          ],
        },
        {
          'sessionId': 999,
          'topics': [
            {'area': 'sport', 'title': 'Lekce, která neexistuje'},
          ],
        },
      ],
    });

    await container.read(topicHistoryBackfillProvider).ensure();

    final topics = await TopicHistoryRepository(db).getAll();
    expect(topics.map((t) => '${t.sessionId}:${t.areaId}'), unorderedEquals(['$work:prace', '$work:technologie', '$hike:priroda']));
    expect(prefs.getBool(TopicHistoryBackfill.doneKey), isTrue);
    final prompt = verify(() => gemini.sendMessage(captureAny(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'))).captured.single as String;
    expect(prompt, contains('#$hike ('));
    expect(prompt, contains('Výlet do Toulovcových Maštalí'));

    // Podruhé se už nic neposílá
    await container.read(topicHistoryBackfillProvider).ensure();
    verifyNever(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')));
  });

  test('a history that already has topics is not backfilled', () async {
    final id = await lesson('Králík Dobas');
    await TopicHistoryRepository(db)
        .replaceForSession(id, DateTime(2026, 11, 21), const [LessonTopic(areaId: 'zvirata', title: 'Dobas')]);

    await container.read(topicHistoryBackfillProvider).ensure();

    verifyNever(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')));
    expect(prefs.getBool(TopicHistoryBackfill.doneKey), isTrue);
  });

  test('a failed backfill is tried again next time', () async {
    await lesson('Grilování na zahradě');
    when(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'))).thenThrow(Exception('503'));

    await container.read(topicHistoryBackfillProvider).ensure();

    expect(prefs.getBool(TopicHistoryBackfill.doneKey), isNull);
    expect(await TopicHistoryRepository(db).isEmpty(), isTrue);
  });

  test('after a failure the backfill pauses instead of retrying on every topic request', () async {
    // 24. 11. při přetížení Gemini čekalo na neúspěšné doplnění každé klepnutí na „Náhodné téma“
    await lesson('Grilování na zahradě');
    var now = DateTime(2026, 11, 24, 19, 41);
    final clockContainer = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      geminiTopicBackfillClientProvider.overrideWithValue(gemini),
      topicHistoryBackfillProvider.overrideWith((ref) => TopicHistoryBackfill(ref, clock: () => now)),
    ]);
    addTearDown(clockContainer.dispose);
    when(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'))).thenThrow(const GeminiOverloadedException('503'));
    final backfill = clockContainer.read(topicHistoryBackfillProvider);

    await backfill.ensure();
    now = now.add(const Duration(minutes: 5));
    await backfill.ensure();
    verify(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema'))).called(1);

    now = now.add(TopicHistoryBackfill.retryPause);
    await backfill.ensure();
    verify(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema'))).called(1);
  });

  test('without network the backfill is tried again on the next request', () async {
    await lesson('Grilování na zahradě');
    when(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'),
        responseSchema: any(named: 'responseSchema'))).thenThrow(const GeminiNetworkException());
    final backfill = container.read(topicHistoryBackfillProvider);

    await backfill.ensure();
    await backfill.ensure();

    verify(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema'))).called(2);
  });

  test('the backfill runs only on flash-lite and leaves 3.8 / 3.6 Flash to the lesson analysis', () {
    // 24. 11. začal zápis na 3.6 Flash (naposledy funkční model) a na rozbor lekce 39 nezbyl limit
    final keyContainer = ProviderContainer(overrides: [apiKeyProvider.overrideWith(_FakeApiKeyNotifier.new)]);
    addTearDown(keyContainer.dispose);

    final client = keyContainer.read(geminiTopicBackfillClientProvider)!;

    expect({client.primaryModelName, ...?client.fallbackModels}, {GeminiModels.flashLite3_5, GeminiModels.flashLite3_1});
  });

  test('backfill with zero saved topics does not mark doneKey so it retries next time', () async {
    await lesson('Grilování na zahradě');
    answer({'sessions': []});

    await container.read(topicHistoryBackfillProvider).ensure();

    expect(prefs.getBool(TopicHistoryBackfill.doneKey), isNull);
    expect(await TopicHistoryRepository(db).isEmpty(), isTrue);
  });

  test('backfill with no analyzed sessions marks doneKey without calling Gemini', () async {
    await container.read(topicHistoryBackfillProvider).ensure();

    verifyNever(() => gemini.sendMessage(any(),
        systemPrompt: any(named: 'systemPrompt'), responseSchema: any(named: 'responseSchema')));
    expect(prefs.getBool(TopicHistoryBackfill.doneKey), isTrue);
  });
}
