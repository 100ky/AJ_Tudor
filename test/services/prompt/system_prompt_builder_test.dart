import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

void main() {
  group('SystemPromptBuilder - Tutor Prompt Tests', () {
    test('buildTutorPrompt includes default tutor persona and conversation rules', () {
      final prompt = SystemPromptBuilder.buildTutorPrompt(
        targetLevel: 'B1',
        isImmersive: false,
      );

      expect(prompt.contains('Jsi AJ Tudor, 29letý rodilý mluvčí z Bristolu v Anglii'), true);
      expect(prompt.contains('PRAVIDLO PŘESNĚ JEDNÉ OTÁZKY'), true);
      expect(prompt.contains('VÝPLŇKOVÁ SLOVA, VÁHÁNÍ A PŘEMÝŠLENÍ'), true);
      expect(prompt.contains('PŘÍSNÝ ZÁKAZ SKÁKÁNÍ DO ŘEČI'), true);
      expect(prompt.contains('ZÁKAZ FORMÁTOVÁNÍ MARKDOWN'), true);
    });

    test('buildTutorPrompt handles normal vs immersive mode properly', () {
      final normalPrompt = SystemPromptBuilder.buildTutorPrompt(
        isImmersive: false,
        targetLevel: 'B1',
      );
      expect(normalPrompt.contains('SOKRATOVSKÁ METODA & SCAFFOLDING'), true);
      expect(normalPrompt.contains('přepni do češtiny'), true);
      expect(normalPrompt.contains('ABSOLUTNÍ ZÁKAZ DVOJITÉHO ÚKOLU'), true);
      expect(normalPrompt.contains('PRAVIDLO 1 KLÍČOVÉ CHYBY NA TAH'), true);
      expect(normalPrompt.contains('LIDSKÉ UZNÁNÍ PŘÍBĚHU'), true);
      expect(normalPrompt.contains('DŮSLEDNOST OPRAVOVÁNÍ'), true);
      expect(normalPrompt.contains('NEZAMĚŇUJ TÉMA ZA FRUSTRACI'), true);

      final immersivePrompt = SystemPromptBuilder.buildTutorPrompt(
        isImmersive: true,
        targetLevel: 'B1',
      );
      expect(immersivePrompt.contains('POHLCUJÍCÍ REŽIM (Immersive Mode)'), true);
      expect(immersivePrompt.contains('Mluv se studentem VÝHRADNĚ anglicky'), true);
      expect(immersivePrompt.contains('Nikdy nepřepínej do češtiny'), true);
    });

    test('buildTutorPrompt configures guidelines according to CEFR levels', () {
      final a1 = SystemPromptBuilder.buildTutorPrompt(targetLevel: 'A1');
      expect(a1.contains('nejjednodušší možná slova a velmi krátké věty (max 3-5 slov)'), true);
      expect(a1.contains('Present Simple'), true);

      final a2 = SystemPromptBuilder.buildTutorPrompt(targetLevel: 'A2');
      expect(a2.contains('jednoduché základní časy'), true);

      final b1 = SystemPromptBuilder.buildTutorPrompt(targetLevel: 'B1');
      expect(b1.contains('standardní běžnou angličtinu'), true);

      final b2 = SystemPromptBuilder.buildTutorPrompt(targetLevel: 'B2');
      expect(b2.contains('přirozenou a plynulou angličtinu (včetně běžných idiomů'), true);
    });

    test('buildTutorPrompt injects scenario context, profile memory, user facts and vocabulary', () {
      final prompt = SystemPromptBuilder.buildTutorPrompt(
        targetLevel: 'B1',
        scenarioContext: 'Roleplay: At the hotel reception in London.',
        userFacts: '["Pracuje jako vývojář", "Má psa Maxe"]',
        vocabulary: '["check-in", "reservation"]',
        recurringErrors: '["Past tense of regular verbs"]',
        memoryBriefing: 'Student struggled with past simple last time.',
        personalFact: 'že zrovna pije zelený čaj',
      );

      expect(prompt.contains('AKTUÁLNÍ SCÉNÁŘ (ROLE-PLAY):'), true);
      expect(prompt.contains('Roleplay: At the hotel reception in London.'), true);
      expect(prompt.contains('CO VÍŠ O STUDENTOVI ("O MNĚ" / OSOBNÍ FAKTA):'), true);
      expect(prompt.contains('Má psa Maxe'), true);
      expect(prompt.contains('SLOVÍČKA, KTERÁ STUDENT ZNÁ'), true);
      expect(prompt.contains('reservation'), true);
      expect(prompt.contains('POZNÁMKA PRO TUTORA O CHYBÁCH'), true);
      expect(prompt.contains('Past tense of regular verbs'), true);
      expect(prompt.contains('KONTEXT Z MINULÉ LEKCE (PAMĚŤ):'), true);
      expect(prompt.contains('Student struggled with past simple last time.'), true);
      expect(prompt.contains('že zrovna pije zelený čaj'), true);
    });
  });

  group('SystemPromptBuilder - Analysis Prompt & Schema Tests', () {
    test('buildAnalysisPrompt includes CEFR calibration, security, STT tolerance, and previous briefing', () {
      final promptWithBriefing = SystemPromptBuilder.buildAnalysisPrompt(
        previousBriefing: 'Minulý briefing o studentovi.',
      );

      expect(promptWithBriefing.contains('PAMĚŤ Z MINULOSTI (Historický kontext):'), true);
      expect(promptWithBriefing.contains('Minulý briefing o studentovi.'), true);
      expect(promptWithBriefing.contains('KRITICKÁ BEZPEČNOSTNÍ INSTRUKCE'), true);
      expect(promptWithBriefing.contains('DŮLEŽITÉ UPOZORNĚNÍ K PŘEPISŮM ŘEČI'), true);
      expect(promptWithBriefing.contains('A1 – Breakthrough'), true);
      expect(promptWithBriefing.contains('A2 – Waystage'), true);
      expect(promptWithBriefing.contains('B1 – Threshold'), true);
      expect(promptWithBriefing.contains('B2 – Vantage'), true);
      expect(promptWithBriefing.contains('MEMORY PRUNING (Zapomínání):'), true);
      expect(promptWithBriefing.contains('SEBE-REFLEXE TUTORA (Self-Correction):'), true);
      expect(promptWithBriefing.contains('EXTRAKCE NOVÝCH OSOBNÍCH FAKTŮ O STUDENTOVI ("O MNĚ")'), true);
      expect(promptWithBriefing.contains('Celá správná vzorová anglická věta'), true);
      expect(promptWithBriefing.contains('ZÁSADA ATOMICKÝCH KARTIČEK'), true);
      expect(promptWithBriefing.contains('targetWordOrPhrase'), true);
    });

    test('getAnalysisResponseSchema provides valid schema structure with all required fields', () {
      final schema = SystemPromptBuilder.getAnalysisResponseSchema();
      expect(schema['type'], 'object');

      final requiredFields = schema['required'] as List<dynamic>;
      expect(requiredFields.contains('topicSummary'), true);
      expect(requiredFields.contains('fluencyScore'), true);
      expect(requiredFields.contains('estimatedLevel'), true);
      expect(requiredFields.contains('totalErrors'), true);
      expect(requiredFields.contains('briefing'), true);
      expect(requiredFields.contains('resolvedErrors'), true);
      expect(requiredFields.contains('vocabulary'), true);
      expect(requiredFields.contains('newLearnedUserFacts'), true);
      expect(requiredFields.contains('errors'), true);

      final properties = schema['properties'] as Map<String, dynamic>;
      final errorsProperty = properties['errors'] as Map<String, dynamic>;
      final errorItems = errorsProperty['items'] as Map<String, dynamic>;
      final errorRequired = errorItems['required'] as List<dynamic>;

      expect(errorRequired.contains('type'), true);
      expect(errorRequired.contains('userSaid'), true);
      expect(errorRequired.contains('targetWordOrPhrase'), true);
      expect(errorRequired.contains('czechCue'), true);
      expect(errorRequired.contains('correctForm'), true);
      expect(errorRequired.contains('explanation'), true);
      expect(errorRequired.contains('czechTranslation'), true);
    });
  });

  group('SystemPromptBuilder - Scenario Planner Prompt & Schema Tests', () {
    test('buildScenarioPlannerPrompt includes user data and anti-school stop-bias', () {
      final prompt = SystemPromptBuilder.buildScenarioPlannerPrompt(
        userInterests: 'Fotbal, automobily',
        recentErrors: 'Past simple vs past continuous',
        currentVocabulary: '["engine", "stadium"]',
        targetLevel: 'B2',
        memoryBriefing: 'Procvičovat minulost.',
      );

      expect(prompt.contains('Fotbal, automobily'), true);
      expect(prompt.contains('Past simple vs past continuous'), true);
      expect(prompt.contains('B2'), true);
      expect(prompt.contains('BEZPEČNOSTNÍ STOP-BIAS'), true);
      expect(prompt.contains('děti'), true);
      expect(prompt.contains('školní jídelna'), true);
    });

    test('getScenarioResponseSchema defines scenario array with valid properties', () {
      final schema = SystemPromptBuilder.getScenarioResponseSchema();
      expect(schema['type'], 'object');
      expect((schema['required'] as List).contains('scenarios'), true);

      final properties = schema['properties'] as Map<String, dynamic>;
      final scenarios = properties['scenarios'] as Map<String, dynamic>;
      final items = scenarios['items'] as Map<String, dynamic>;
      final required = items['required'] as List<dynamic>;

      expect(required.contains('id'), true);
      expect(required.contains('title'), true);
      expect(required.contains('description'), true);
      expect(required.contains('tutorInstruction'), true);
      expect(required.contains('difficulty'), true);
    });
  });

  group('SystemPromptBuilder - Topic Preparation Prompt & Schema Tests', () {
    test('buildTopicPreparationPrompt formats prompt and formats forbidden avoidTopics', () {
      final prompt = SystemPromptBuilder.buildTopicPreparationPrompt(
        targetLevel: 'B1',
        userFacts: '["Pracuje jako lékař"]',
        recentTopics: 'Kavárny',
        recentTranscriptsSnippet: 'Student: Hello\nTudor: Hi',
        avoidTopics: ['Kavárny', 'Lékařství'],
      );

      expect(prompt.contains('PŘÍSNĚ ZAKÁZANÁ TÉMATA'), true);
      expect(prompt.contains('- "Kavárny"'), true);
      expect(prompt.contains('- "Lékařství"'), true);
      expect(prompt.contains('Pracuje jako lékař'), true);
      expect(prompt.contains('REÁLNÁ HISTORIE NEDÁVNÝCH ROZHOVORŮ'), true);
    });

    test('buildRandomTopicPreparationPrompt sets wildcard guidelines ignoring history', () {
      final wildcardPrompt = SystemPromptBuilder.buildRandomTopicPreparationPrompt(
        targetLevel: 'B1',
        avoidTopics: ['Cestování časem'],
      );

      expect(wildcardPrompt.contains('Divokou kartu / Wildcard'), true);
      expect(wildcardPrompt.contains('ABSOLUTNÍ IGNOROVÁNÍ HISTORIE'), true);
      expect(wildcardPrompt.contains('ZÁKAZ NUDNÝCH KLIŠÉ'), true);
      expect(wildcardPrompt.contains('- "Cestování časem"'), true);
    });

    test('getTopicPreparationResponseSchema includes topicTitle, openerEn, rationale', () {
      final schema = SystemPromptBuilder.getTopicPreparationResponseSchema();
      expect(schema['type'], 'object');
      final required = schema['required'] as List<dynamic>;
      expect(required.contains('topicTitle'), true);
      expect(required.contains('openerEn'), true);
      expect(required.contains('rationale'), true);
    });

    test('buildFactExtractionFromHistoryPrompt and schema provide structured extraction', () {
      final prompt = SystemPromptBuilder.buildFactExtractionFromHistoryPrompt();
      expect(prompt.contains('Domácí mazlíčky'), true);
      expect(prompt.contains('Koníčky a záliby'), true);
      expect(prompt.contains('Práci a profesi'), true);

      final schema = SystemPromptBuilder.getFactExtractionSchema();
      expect(schema['type'], 'object');
      expect((schema['required'] as List).contains('facts'), true);
    });
  });

  group('SystemPromptBuilder - Grammar Drill & Personal Facts Tests', () {
    test('buildGrammarDrillPrompt formats drill trainer instructions', () {
      final prompt = SystemPromptBuilder.buildGrammarDrillPrompt(
        recurringErrors: 'Present perfect simple vs continuous',
        targetLevel: 'B1',
        vocabulary: '["since", "for", "already"]',
      );

      expect(prompt.contains('Jsi AJ Tudor – gramatický trenér pro české studenty angličtiny.'), true);
      expect(prompt.contains('Present perfect simple vs continuous'), true);
      expect(prompt.contains('B1'), true);
      expect(prompt.contains('since'), true);
      expect(prompt.contains('FORMÁT CVIČENÍ:'), true);
    });

    test('getRandomPersonalFact returns non-empty Czech personal fact about Tudor', () {
      final fact = SystemPromptBuilder.getRandomPersonalFact();
      expect(fact.isNotEmpty, true);
      expect(fact.startsWith('že '), true);
    });
  });
}
