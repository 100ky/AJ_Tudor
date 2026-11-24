import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/services/topics/topic_history_backfill.dart';
import 'package:aj_tudor/services/topics/topic_plan_loader.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sessions = SessionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> makeContainer(Map<String, Object> prefsMap) async {
    SharedPreferences.setMockInitialValues(prefsMap);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  final loaderProvider = FutureProvider((ref) => loadTopicPlan(ref));

  test('returns empty plan when topic_history is empty, backfill is not done, and analyzed sessions exist', () async {
    final id = (await sessions.startNewSession()).getOrThrow();
    await sessions.updateSessionAnalysis(sessionId: id, topicSummary: 'Práce v IT', fluencyScore: 0.6, totalErrors: 0);
    final container = await makeContainer({});

    final plan = await container.read(loaderProvider.future);

    expect(plan.isEmpty, isTrue);
  });

  test('returns three new areas when backfill is done or there are no analyzed sessions', () async {
    final id = (await sessions.startNewSession()).getOrThrow();
    await sessions.updateSessionAnalysis(sessionId: id, topicSummary: 'Práce v IT', fluencyScore: 0.6, totalErrors: 0);
    final containerDone = await makeContainer({TopicHistoryBackfill.doneKey: true});

    final planDone = await containerDone.read(loaderProvider.future);
    expect(planDone.offers, hasLength(3));
    expect(planDone.offers.every((o) => o.isNew), isTrue);

    final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(freshDb.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final containerFresh = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(freshDb),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(containerFresh.dispose);

    final planFresh = await containerFresh.read(loaderProvider.future);
    expect(planFresh.offers, hasLength(3));
  });
}
