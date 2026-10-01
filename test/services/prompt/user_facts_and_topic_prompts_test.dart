import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/agents/topic_preparation_agent.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

void main() {
  group('SystemPromptBuilder Tests for User Facts & Topic Preparation', () {
    test('buildTutorPrompt includes user facts and anti-repetition rules', () {
      const facts = '["Má psa jménem Rex", "Pracuje v IT"]';
      final prompt = SystemPromptBuilder.buildTutorPrompt(
        userFacts: facts,
        targetLevel: 'B1',
      );

      expect(prompt.contains('CO VÍŠ O STUDENTOVI ("O MNĚ" / OSOBNÍ FAKTA)'), true);
      expect(prompt.contains('Má psa jménem Rex'), true);
      expect(prompt.contains('PŘÍSNÝ ZÁKAZ OPAKOVANÝCH ZÁKLADNÍCH DOTAZŮ'), true);
      expect(prompt.contains('Do you have any pets?'), true);
    });

    test('buildAnalysisPrompt and schema contains newLearnedUserFacts', () {
      final prompt = SystemPromptBuilder.buildAnalysisPrompt();
      expect(prompt.contains('EXTRAKCE NOVÝCH OSOBNÍCH FAKTŮ O STUDENTOVI ("O MNĚ")'), true);

      final schema = SystemPromptBuilder.getAnalysisResponseSchema();
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('newLearnedUserFacts'), true);
      expect((schema['required'] as List).contains('newLearnedUserFacts'), true);
    });

    test('buildTopicPreparationPrompt and schema is valid', () {
      final prompt = SystemPromptBuilder.buildTopicPreparationPrompt(
        targetLevel: 'B1',
        userFacts: '["Má psa"]',
        recentTopics: 'Filmy a kino',
        recentTranscriptsSnippet: 'Student: I watched Inception yesterday.\nTudor: Great movie!',
        memoryBriefing: 'Procvičit minulý čas',
      );

      expect(prompt.contains('PŘÍSNÝ ZÁKAZ OPAKOVANÝCH OTÁZEK NA ZNÁMÁ FAKTA'), true);
      expect(prompt.contains('ZÁKAZ BIZARNOSTÍ'), true);
      expect(prompt.contains('Má psa'), true);
      expect(prompt.contains('Filmy a kino'), true);
      expect(prompt.contains('Inception'), true);

      final schema = SystemPromptBuilder.getTopicPreparationResponseSchema();
      expect((schema['required'] as List).contains('topicTitle'), true);
      expect((schema['required'] as List).contains('openerEn'), true);
      expect((schema['required'] as List).contains('rationale'), true);
    });

    test('buildTopicPreparationPrompt correctly embeds avoidTopics block', () {
      final prompt = SystemPromptBuilder.buildTopicPreparationPrompt(
        targetLevel: 'B1',
        avoidTopics: ['Hudba z dětství', 'Oblíbené filmy'],
      );

      expect(prompt.contains('PŘÍSNĚ ZAKÁZANÁ TÉMATA'), true);
      expect(prompt.contains('Hudba z dětství'), true);
      expect(prompt.contains('Oblíbené filmy'), true);
    });

    test('buildFactExtractionFromHistoryPrompt and schema is valid', () {
      final prompt = SystemPromptBuilder.buildFactExtractionFromHistoryPrompt();
      expect(prompt.contains('Domácí mazlíčky'), true);
      expect(prompt.contains('Koníčky a záliby'), true);

      final schema = SystemPromptBuilder.getFactExtractionSchema();
      expect((schema['required'] as List).contains('facts'), true);
    });

    test('buildRandomTopicPreparationPrompt embeds wildcard instructions and avoidTopics', () {
      final prompt = SystemPromptBuilder.buildRandomTopicPreparationPrompt(
        targetLevel: 'B2',
        avoidTopics: ['Cestování vlakem'],
      );

      expect(prompt.contains('Divokou kartu / Wildcard'), true);
      expect(prompt.contains('ABSOLUTNÍ IGNOROVÁNÍ HISTORIE'), true);
      expect(prompt.contains('PŘÍSNĚ ZAKÁZANÁ TÉMATA'), true);
      expect(prompt.contains('Cestování vlakem'), true);
      expect(prompt.contains('B2'), true);
    });

    test('PreparedTopic serialization supports isRandomTopic flag', () {
      final topic = PreparedTopic(
        title: 'Cestování v čase',
        openerEn: 'If you had a time machine, where would you go?',
        rationale: 'Divoká karta',
        preparedAt: DateTime.now(),
        isRandomTopic: true,
      );

      final json = topic.toJson();
      expect(json['isRandomTopic'], true);

      final restored = PreparedTopic.fromJson(json);
      expect(restored.isRandomTopic, true);
      expect(restored.title, 'Cestování v čase');

      final defaultRestored = PreparedTopic.fromJson({
        'title': 'Klasické téma',
        'openerEn': 'Hello!',
        'rationale': 'Z historie',
      });
      expect(defaultRestored.isRandomTopic, false);
    });
  });
}
