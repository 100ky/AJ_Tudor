// Test promptu režiséra (VoiceDirectorAgent) na skutečných chvílích z lekcí.
//
// Každý případ je okamžik, kdy v lekci běžel režisér: posledních 12 replik
// a průběžný souhrn hovoru, jak je tehdy viděl. Prompt i schéma odpovědi se
// sestaví stejně jako v aplikaci a rada se vyhodnotí kontrolami (checks.dart)
// a rozhodčím modelem.
//
//   dart run tool/prompt_eval/director.dart --label director-baseline [--runs 2] [--only 19-202932] [--resume]
//   dart run tool/prompt_eval/director.dart --compare director-baseline director-candidate
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

import 'checks.dart';
import 'common.dart';

Future<void> main(List<String> args) async {
  final options = EvalOptions.parse(args, defaultLabel: 'director-baseline');
  if (options.compare != null) {
    await compareRuns(options.compare!.$1, options.compare!.$2);
    return;
  }
  final apiKey = apiKeyFromEnvironment();
  if (apiKey == null) return;

  final data = jsonDecode(await File.fromUri(privateDir.resolve('director_cases.json')).readAsString())
      as Map<String, dynamic>;
  final profile = data['profile'] as Map<String, dynamic>;
  final cases = (data['cases'] as List)
      .cast<Map<String, dynamic>>()
      .where((c) => options.only.isEmpty || options.only.contains(c['id']))
      .toList();
  stdout.writeln('Případů režiséra: ${cases.length}, opakování: ${options.runs}');

  final results = options.resume ? loadFinishedCases(options.label) : <Map<String, dynamic>>[];
  final finished = {for (final c in results) c['id']};
  Map<String, Object?> report() => {
        'label': options.label,
        'agent': 'director',
        'date': DateTime.now().toIso8601String(),
        'runs': options.runs,
        'judge': options.judge,
        'cases': results,
      };

  // Jeden případ po druhém: souběžné dotazy rychle vyčerpaly bezplatnou kvótu
  try {
    for (final testCase in cases.where((c) => !finished.contains(c['id']))) {
      results.add(await _runCase(apiKey, profile, testCase, options));
      await saveReport(report());
    }
  } on QuotaExceeded catch (e) {
    stdout.writeln('\n⛔ $e. Test končí, hotové případy jsou uložené (pokračování: --resume).');
    exitCode = 3;
  }
  await saveReport(report(), announce: true);
}

Future<Map<String, Object?>> _runCase(
  String apiKey,
  Map<String, dynamic> profile,
  Map<String, dynamic> testCase,
  EvalOptions options,
) async {
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final prompt = SystemPromptBuilder.buildDirectorPrompt(
    targetLevel: profile['targetLevel'] as String? ?? 'B1',
    userFacts: profile['userFacts'] as String?,
    recentTopics: profile['topicPreferences'] as String?,
    rollingSummary: testCase['rollingSummary'] as String?,
  );
  // Stejný vstup jako VoiceDirectorAgent.onTurnCompleted
  final transcript = '<transcript>\n${transcriptOf(history, tutorName: 'AJ Tudor')}\n</transcript>';
  final situation = directorSituation(history);
  final original = testCase['original'] as Map<String, dynamic>;
  final replies = <Map<String, Object?>>[];

  for (var run = 1; run <= options.runs; run++) {
    Map<String, dynamic> output;
    try {
      (output, _) = await withRetry(() => generateJson(
            apiKey,
            systemPrompt: prompt,
            userText: transcript,
            schema: SystemPromptBuilder.getDirectorResponseSchema(),
          ));
    } on QuotaExceeded {
      rethrow;
    } catch (e) {
      stdout.writeln('${testCase['id']} [$run] ⚠️ režisér neodpověděl: $e');
      replies.add({'error': e.toString()});
      continue;
    }
    final whisper = output['whisperToTutor']?.toString().trim() ?? '';
    final hint = output['studentHint']?.toString().trim() ?? '';
    final needsPivot = output['needsPivot'] == true;
    final checks = checkDirector(whisper: whisper, hint: hint, needsPivot: needsPivot, history: history);
    Map<String, Object?>? verdict;
    if (options.judge) {
      await Future<void>.delayed(requestPause);
      verdict = await judge(apiKey, rules: _judgeRules, question: '''Posledních 12 replik hovoru:
${transcriptOf(history)}

Výstup režiséra:
- rada tutorovi (whisperToTutor): ${whisper.isEmpty ? '(prázdná)' : whisper}
- nápověda studentovi (studentHint): ${hint.isEmpty ? '(prázdná)' : hint}
- změnit téma (needsPivot): $needsPivot

Je výstup režiséra v této chvíli vhodný? Vrať pass a zdůvodnění (jedna věta česky).''');
    }
    final passed = replyPassed(checks.map((c) => c.passed), verdict);
    replies.add({
      'text': 'RADA: ${whisper.isEmpty ? '—' : whisper} | NÁPOVĚDA: ${hint.isEmpty ? '—' : hint} | '
          'téma ${output['topicHealth']}/10${needsPivot ? ', změnit' : ''}',
      'checks': [for (final c in checks) c.toJson()],
      'judge': verdict,
      'passed': passed,
    });
    final failed = checks.where((c) => !c.passed).map((c) => c.name).join(', ');
    stdout.writeln('${testCase['id']} [$run] ${switch (passed) { true => '✓', false => '✗', _ => '?' }} '
        '${failed.isEmpty ? '' : '($failed) '}${verdict != null && verdict['pass'] != true ? '— ${verdict['reason']}' : ''}');
    await Future<void>.delayed(requestPause);
  }

  final lastTwo = history.length > 2 ? history.sublist(history.length - 2) : history;
  return {
    'id': testCase['id'],
    'kind': situation,
    'student': transcriptOf(lastTwo).replaceAll('\n', ' / '),
    'expect': 'Původní rada v lekci: ${original['whisper'] ?? '—'}',
    'replies': replies,
  };
}

const String _judgeRules = '''Jsi přísný, ale férový hodnotitel režiséra živé hlasové lekce angličtiny.
Režisér běží na pozadí hovoru studenta (Čech, úroveň B1) s AI tutorem. Vrací radu tutorovi (whisperToTutor), krátkou nápovědu na displej studenta (studentHint) a doporučení změnit téma (needsPivot).
Rada se k tutorovi dostane až po další odpovědi studenta, proto má jít o směr pro další tahy, ne o reakci na poslední větu.
Dobrá rada: drží aktuální téma, dokud žije, nebo navrhne nový úhel z toho, o čem student právě mluví. Nevrací hovor k faktům z profilu (jídlo, vaření, bylinky, koníčky, narozeniny), pokud o nich v hovoru není řeč, a nepoužívá fakta vázaná na čas („dnes“, „právě“). Neřeší gramatiku ani opravy, to je práce tutora, a nikdy tutorovi neradí, aby opravy přeskočil nebo „šel dál“. Když tutor právě opravuje a čeká na zopakování věty, nebo když se student loučí, má být rada prázdná (u loučení nanejvýš vlídně se rozloučit).
Dobrá nápověda je krátká věta, kterou student může v té chvíli opravdu říct, a nevymýšlí si o něm fakta.
Posuzuj, zda je výstup režiséra v této chvíli vhodný podle těchto pravidel.''';
