import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aj_tudor/core/config/config_providers.dart';
import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/data/data_providers.dart';
import 'package:aj_tudor/features/conversation/grammar_drill_controller.dart';
import 'package:aj_tudor/services/gemini/gemini_batch_client.dart';
import 'package:aj_tudor/services/gemini/gemini_providers.dart';

class MockGeminiBatchClient extends Mock implements GeminiBatchClient {}

void main() {
  group('drillFocusErrors', () {
    test('returns at most 4 errors from a JSON list', () {
      expect(drillFocusErrors('["a", "b", "c", "d", "e"]'), ['a', 'b', 'c', 'd']);
    });

    test('falls back to comma separated legacy text', () {
      expect(drillFocusErrors('členy,  předložky , ,časy'), ['členy', 'předložky', 'časy']);
    });

    test('treats empty values as no errors', () {
      expect(drillFocusErrors(null), isEmpty);
      expect(drillFocusErrors(''), isEmpty);
      expect(drillFocusErrors('[]'), isEmpty);
    });
  });

  group('GrammarDrillController', () {
    late MockGeminiBatchClient client;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      client = MockGeminiBatchClient();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          geminiBatchClientProvider.overrideWithValue(client),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
    });

    tearDown(() => container.dispose());

    GrammarDrillController drill() => container.read(grammarDrillControllerProvider.notifier);
    GrammarDrillState state() => container.read(grammarDrillControllerProvider);

    test('startDrill shows the request and the tutor reply', () async {
      when(() => client.sendMessage(any(), systemPrompt: any(named: 'systemPrompt')))
          .thenAnswer((_) async => 'Rule + 3 sentences');

      await drill().startDrill('Conditionals');

      expect(state().isLoading, false);
      expect(state().messages.map((m) => m.text),
          ['Procvičit téma: Conditionals', 'Rule + 3 sentences']);
      expect(state().messages.map((m) => m.isUser), [true, false]);
    });

    test('send appends the student answer and the correction', () async {
      when(() => client.sendMessage(any(), systemPrompt: any(named: 'systemPrompt')))
          .thenAnswer((_) async => 'Correct!');

      await drill().send('I have been there.');

      expect(state().messages.map((m) => m.text), ['I have been there.', 'Correct!']);
    });

    test('a failed request becomes a tutor message instead of an exception', () async {
      when(() => client.sendMessage(any(), systemPrompt: any(named: 'systemPrompt')))
          .thenThrow(Exception('offline'));

      await drill().send('Hello');

      expect(state().isLoading, false);
      expect(state().messages.last.text, contains('Chyba při komunikaci'));
      expect(state().messages.last.isUser, false);
    });

    test('changing the chat model clears the drill', () async {
      when(() => client.sendMessage(any(), systemPrompt: any(named: 'systemPrompt')))
          .thenAnswer((_) async => 'Correct!');
      await drill().send('Hello');
      expect(state().messages, isNotEmpty);

      final otherModel = GeminiModels.allowedChatModels
          .firstWhere((m) => m != container.read(modelProvider));
      await container.read(modelProvider.notifier).saveModel(otherModel);

      expect(state().messages, isEmpty);
    });

    test('reset clears the conversation', () async {
      when(() => client.sendMessage(any(), systemPrompt: any(named: 'systemPrompt')))
          .thenAnswer((_) async => 'Correct!');
      await drill().send('Hello');

      drill().reset();

      expect(state().messages, isEmpty);
    });
  });
}
