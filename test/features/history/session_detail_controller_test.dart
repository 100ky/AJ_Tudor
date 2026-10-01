import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/data/database/app_database.dart';
import 'package:aj_tudor/data/repositories/session_repository.dart';
import 'package:aj_tudor/features/history/session_detail_controller.dart';
import 'package:aj_tudor/services/agents/scenario_planner_agent.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';

class MockScenarioPlannerAgent extends Mock implements ScenarioPlannerAgent {}

class _FakeBatchClient extends GeminiBatchClient {
  final prompts = <String>[];
  _FakeBatchClient() : super('dummy_key', 'dummy_model');

  @override
  Future<String> sendMessage(
    String text, {
    Map<String, dynamic>? responseSchema,
    String? systemPrompt,
    double? temperature,
  }) async {
    prompts.add(text);
    return '  Great question! How was your day?  ';
  }
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late _FakeBatchClient client;
  late MockScenarioPlannerAgent planner;
  late ProviderContainer container;

  ProviderContainer makeContainer({GeminiBatchClient? gemini}) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        geminiBatchClientProvider.overrideWithValue(gemini),
        scenarioPlannerAgentProvider.overrideWithValue(planner),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionRepository(db);
    client = _FakeBatchClient();
    planner = MockScenarioPlannerAgent();
    when(() => planner.planScenarios()).thenAnswer((_) async {});
    container = makeContainer(gemini: client);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Session> createSession() async {
    final id = (await repo.startNewSession()).getOrThrow();
    return (await repo.watchAllSessions().first).firstWhere((s) => s.id == id);
  }

  group('SessionDetailController', () {
    test('canChat reflects whether a Gemini client is available', () {
      expect(container.read(sessionDetailControllerProvider).canChat, true);

      final noKey = makeContainer();
      addTearDown(noKey.dispose);
      expect(noKey.read(sessionDetailControllerProvider).canChat, false);
    });

    test('sendFollowUp stores the student message and the trimmed tutor reply', () async {
      final session = await createSession();
      var studentSaved = false;

      await container.read(sessionDetailControllerProvider).sendFollowUp(
            session,
            'Can we talk about travel?',
            onStudentMessageSaved: () => studentSaved = true,
          );

      expect(studentSaved, true);
      final transcripts = await repo.getTranscripts(session.id);
      expect(transcripts.map((t) => t.speaker), ['user', 'tutor']);
      expect(transcripts.first.content, 'Can we talk about travel?');
      expect(transcripts.last.content, 'Great question! How was your day?');
    });

    test('sendFollowUp sends only the last 10 lines of the lesson as context', () async {
      final session = await createSession();
      for (var i = 0; i < 12; i++) {
        await repo.addTranscript(sessionId: session.id, speaker: 'tutor', content: 'line $i');
      }

      await container.read(sessionDetailControllerProvider).sendFollowUp(session, 'Hi!');

      final prompt = client.prompts.single;
      expect(prompt, contains('Nová zpráva od studenta: "Hi!"'));
      expect(prompt, contains('Tudor: line 11'));
      expect(prompt, contains('Tudor: line 3'));
      expect(prompt, isNot(contains('Tudor: line 2\n')));
      expect(prompt, contains('Student: Hi!'));
    });

    test('deleteSession removes the lesson and replans scenarios', () async {
      final session = await createSession();

      final result = await container.read(sessionDetailControllerProvider).deleteSession(session.id);

      expect(result.isSuccess, true);
      expect(await repo.watchAllSessions().first, isEmpty);
      verify(() => planner.planScenarios()).called(1);
    });
  });
}
