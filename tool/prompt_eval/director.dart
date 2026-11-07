// Test promptu režiséra (VoiceDirectorAgent) na skutečných chvílích z lekcí.
//
// Každý případ je okamžik, kdy v lekci běžel režisér: posledních 12 replik
// a průběžný souhrn hovoru, jak je tehdy viděl. Prompt i schéma odpovědi se
// sestaví stejně jako v aplikaci a rada se vyhodnotí kontrolami (checks.dart)
// a rozhodčím modelem.
//
//   dart run tool/prompt_eval/director.dart --dry-run                  (jen plán a odhad spotřeby)
//   dart run tool/prompt_eval/director.dart --label director-original --original --no-judge
//                                          (skutečné rady z lekcí, bez volání API)
//   dart run tool/prompt_eval/director.dart --label director-candidate --max-requests 100 [--runs 1] [--only 19-202932] [--resume]
//   dart run tool/prompt_eval/director.dart --label director-candidate --judge-only --model gemini-3.6-flash --max-requests 80
//                                          (ohodnotí uložené výstupy rozhodčím)
//   dart run tool/prompt_eval/director.dart --compare director-original director-candidate
//   dart run tool/prompt_eval/director.dart --label director-karticky --cases tool/prompt_eval/private/director_cases_karticky.json
//                                          (případy s dnešními kartičkami: soubor má navíc pole dueCards)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

import 'checks.dart';
import 'common.dart';

Future<void> main(List<String> args) async {
  final options = EvalOptions.parse(args, defaultLabel: 'director-baseline');
  if (options.compare != null) {
    await compareRuns(options.compare!.$1, options.compare!.$2);
    return;
  }
  final casesFile = options.casesFile != null
      ? File(options.casesFile!)
      : File.fromUri(privateDir.resolve('director_cases.json'));
  final data = jsonDecode(await casesFile.readAsString()) as Map<String, dynamic>;
  final profile = data['profile'] as Map<String, dynamic>;
  // Kartičky na dnešní opakování (od nejstarší); režisér dostane zásobu jako v aplikaci
  final cards = _directorPool(data['dueCards'] as List?);
  final cases = (data['cases'] as List)
      .cast<Map<String, dynamic>>()
      .where((c) => options.only.isEmpty || options.only.contains(c['id']))
      // Skutečný výstup má jen chvíle, kdy volání režiséra v lekci neselhalo
      .where(
        (c) =>
            !options.original ||
            (c['original'] as Map).containsKey('needsPivot'),
      )
      .toList();
  final runs = options.original ? 1 : options.runs;

  if (options.judgeOnly) {
    final apiKey = apiKeyFromEnvironment();
    if (apiKey == null) return;
    RequestBudget.start(options.maxRequests);
    final byId = {for (final c in cases) c['id']: c};
    await judgeSavedReplies(
      apiKey: apiKey,
      options: options,
      rules: _judgeRules,
      question: (resultCase, reply) {
        final output = reply['output'] as Map<String, dynamic>;
        return _judgeQuestion(
          (byId[resultCase['id']]!['history'] as List).cast<Map<String, dynamic>>(),
          whisper: output['whisper'] as String,
          hint: output['hint'] as String,
          needsPivot: output['needsPivot'] == true,
          cards: cards,
          flashcardId: (output['flashcardId'] as num?)?.toInt() ?? 0,
        );
      },
    );
    return;
  }
  stdout.writeln(
    'Případů režiséra: ${cases.length}, opakování: $runs${options.original ? ' (skutečné rady z lekcí)' : ''}'
    '${cards.isEmpty ? '' : ', kartiček v zásobě: ${cards.length}'}',
  );

  final results = options.resume
      ? loadFinishedCases(options.label, runs: runs)
      : <Map<String, dynamic>>[];
  final finished = {for (final c in results) c['id']};
  final pending = cases.where((c) => !finished.contains(c['id'])).toList();

  if (options.dryRun) {
    var requestChars = 0;
    var judgeChars = 0;
    for (final c in pending) {
      final history = (c['history'] as List).cast<Map<String, dynamic>>();
      final transcriptChars = transcriptOf(history).length;
      if (!options.original) {
        requestChars += _promptFor(profile, c, cards).length + transcriptChars;
      }
      judgeChars += _judgeRules.length + transcriptChars + 400;
    }
    printDryRun(
      agent: options.original
          ? 'režisér, jen rozhodčí nad skutečnými radami'
          : 'režisér',
      model: options.original ? '(žádný, rady z logů)' : options.model ?? textModels.first,
      cases: options.original ? 0 : pending.length,
      judgedCases: pending.length,
      runs: runs,
      judge: options.judge,
      requestChars: requestChars,
      judgeChars: judgeChars,
    );
    return;
  }
  final needsKey = !options.original || options.judge;
  final apiKey = needsKey ? apiKeyFromEnvironment() : '';
  if (apiKey == null) return;
  RequestBudget.start(options.maxRequests);
  Map<String, Object?> report() => {
    'label': options.label,
    'agent': options.original ? 'director-original' : 'director',
    'date': DateTime.now().toIso8601String(),
    'runs': runs,
    'judge': options.judge,
    'cases': results,
  };

  // Jeden případ po druhém: souběžné dotazy rychle vyčerpaly bezplatnou kvótu
  try {
    for (final testCase in pending) {
      results.add(await _runCase(apiKey, profile, testCase, options, runs, cards));
      await saveReport(report());
    }
  } on StopRun catch (e) {
    stdout.writeln(
      '\n⛔ $e. Test končí, hotové případy jsou uložené (pokračování: --resume).',
    );
    exitCode = 3;
  }
  await saveReport(report(), announce: true);
  stdout.writeln(
    'Požadavků na API v tomto běhu: ${RequestBudget.used} z ${options.maxRequests}',
  );
}

Future<Map<String, Object?>> _runCase(
  String apiKey,
  Map<String, dynamic> profile,
  Map<String, dynamic> testCase,
  EvalOptions options,
  int runs,
  List<ConversationCard> cards,
) async {
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final prompt = _promptFor(profile, testCase, cards);
  // Stejný vstup jako VoiceDirectorAgent.onTurnCompleted
  final transcript =
      '<transcript>\n${transcriptOf(history, tutorName: 'AJ Tudor')}\n</transcript>';
  final situation = directorSituation(history);
  final original = testCase['original'] as Map<String, dynamic>;
  final replies = <Map<String, Object?>>[];

  for (var run = 1; run <= runs; run++) {
    Map<String, dynamic> output;
    try {
      if (options.original) {
        output = {
          'whisperToTutor': original['whisper'] ?? '',
          'studentHint': original['hint'] ?? '',
          'needsPivot': original['needsPivot'],
          'topicHealth': '?',
        };
      } else {
        (output, _) = await withRetry(
          () => generateJson(
            apiKey,
            systemPrompt: prompt,
            userText: transcript,
            schema: SystemPromptBuilder.getDirectorResponseSchema(),
            models: options.model != null ? [options.model!] : textModels,
          ),
        );
      }
    } on StopRun {
      rethrow;
    } catch (e) {
      stdout.writeln('${testCase['id']} [$run] ⚠️ režisér neodpověděl: $e');
      replies.add({'error': e.toString()});
      continue;
    }
    final whisper = output['whisperToTutor']?.toString().trim() ?? '';
    final hint = output['studentHint']?.toString().trim() ?? '';
    final needsPivot = output['needsPivot'] == true;
    final flashcardId = (output['flashcardId'] as num?)?.toInt() ?? 0;
    final card = cards.where((c) => c.id == flashcardId).firstOrNull;
    final checks = checkDirector(
      whisper: whisper,
      hint: hint,
      needsPivot: needsPivot,
      history: history,
      cards: cards,
      flashcardId: flashcardId,
    );
    Map<String, Object?>? verdict;
    // Rozhodčí jen u výstupů, které prošly automatickými kontrolami: jinak neprošly tak jako tak
    if (options.judge && checks.every((c) => c.passed)) {
      await Future<void>.delayed(requestPause);
      verdict = await judge(
        apiKey,
        rules: _judgeRules,
        question: _judgeQuestion(
          history,
          whisper: whisper,
          hint: hint,
          needsPivot: needsPivot,
          cards: cards,
          flashcardId: flashcardId,
        ),
        models: options.judgeModels,
      );
    }
    final passed = replyPassed(checks.map((c) => c.passed), verdict);
    replies.add({
      'text':
          'RADA: ${whisper.isEmpty ? '—' : whisper} | NÁPOVĚDA: ${hint.isEmpty ? '—' : hint} | '
          'téma ${output['topicHealth']}/10${needsPivot ? ', změnit' : ''}'
          '${flashcardId == 0 ? '' : ' | KARTIČKA: #$flashcardId ${card?.english ?? '(mimo nabídku)'}'}',
      'output': {'whisper': whisper, 'hint': hint, 'needsPivot': needsPivot, 'flashcardId': flashcardId},
      'checks': [for (final c in checks) c.toJson()],
      'judge': verdict,
      'passed': passed,
    });
    final failed = checks.where((c) => !c.passed).map((c) => c.name).join(', ');
    stdout.writeln(
      '${testCase['id']} [$run] ${switch (passed) {
        true => '✓',
        false => '✗',
        _ => '?',
      }} '
      '${failed.isEmpty ? '' : '($failed) '}${verdict != null && verdict['pass'] != true ? '— ${verdict['reason']}' : ''}',
    );
    if (verdict != null || !options.original) {
      await Future<void>.delayed(requestPause);
    }
  }

  final lastTwo = history.length > 2
      ? history.sublist(history.length - 2)
      : history;
  return {
    'id': testCase['id'],
    'kind': situation,
    'student': transcriptOf(lastTwo).replaceAll('\n', ' / '),
    'expect': 'Původní rada v lekci: ${original['whisper'] ?? '—'}',
    'replies': replies,
  };
}

/// Otázka pro rozhodčího: posledních 12 replik a výstup režiséra.
String _judgeQuestion(
  List<Map<String, dynamic>> history, {
  required String whisper,
  required String hint,
  required bool needsPivot,
  List<ConversationCard> cards = const [],
  int flashcardId = 0,
}) {
  final card = cards.where((c) => c.id == flashcardId).firstOrNull;
  final offered = cards.isEmpty
      ? ''
      : '\nKartičky nabídnuté režisérovi (výrazy, které se student učí):\n'
            '${cards.map((c) => '#${c.id}: ${c.czech} → ${c.english}').join('\n')}\n';
  final woven = cards.isEmpty
      ? ''
      : '\n- vpletená kartička (flashcardId): '
            '${card == null ? 'žádná' : '#${card.id}: ${card.czech} → ${card.english}'}';
  return '''Posledních 12 replik hovoru:
${transcriptOf(history)}
$offered
Výstup režiséra:
- rada tutorovi (whisperToTutor): ${whisper.isEmpty ? '(prázdná)' : whisper}
- nápověda studentovi (studentHint): ${hint.isEmpty ? '(prázdná)' : hint}
- změnit téma (needsPivot): $needsPivot$woven

Je výstup režiséra v této chvíli vhodný? Vrať pass a zdůvodnění (jedna věta česky).''';
}

/// Zásoba kartiček pro režiséra jako ve VoiceTutorAgent: dnešní kartičky bez výslovnosti,
/// jen ty, které hovor dokáže ověřit, nejvýš [ConversationCards.poolSize].
List<ConversationCard> _directorPool(List? dueCards) {
  if (dueCards == null) return const [];
  return ConversationCards([
    for (final card in dueCards.cast<Map<String, dynamic>>())
      if (card['errorType'] != 'pronunciation')
        ConversationCard(
          id: card['id'] as int,
          czech: (card['front'] as String).trim(),
          english: (card['back'] as String).trim(),
        ),
  ]).directorPool();
}

/// Prompt režiséra pro případ, stejně jako ve VoiceDirectorAgent.onTurnCompleted.
String _promptFor(
  Map<String, dynamic> profile,
  Map<String, dynamic> testCase,
  List<ConversationCard> cards,
) => SystemPromptBuilder.buildDirectorPrompt(
  targetLevel: profile['targetLevel'] as String? ?? 'B1',
  userFacts: profile['userFacts'] as String?,
  recentTopics: profile['topicPreferences'] as String?,
  rollingSummary: testCase['rollingSummary'] as String?,
  cards: cards,
);

const String _judgeRules =
    '''Jsi přísný, ale férový hodnotitel režiséra živé hlasové lekce angličtiny.
Režisér běží na pozadí hovoru studenta (Čech, úroveň B1) s AI tutorem. Vrací radu tutorovi (whisperToTutor), krátkou nápovědu na displej studenta (studentHint) a doporučení změnit téma (needsPivot).
Rada se k tutorovi dostane až po další odpovědi studenta, proto má jít o směr pro další tahy, ne o reakci na poslední větu.
Dobrá rada: drží aktuální téma, dokud žije, nebo navrhne nový úhel z toho, o čem student právě mluví. Nevrací hovor k faktům z profilu (jídlo, vaření, bylinky, koníčky, narozeniny), pokud o nich v hovoru není řeč, a nepoužívá fakta vázaná na čas („dnes“, „právě“). Neřeší gramatiku ani opravy, to je práce tutora, a nikdy tutorovi neradí, aby opravy přeskočil nebo „šel dál“. Když tutor právě opravuje a čeká na zopakování věty, nebo když se student loučí, má být rada prázdná (u loučení nanejvýš vlídně se rozloučit).
Dobrá nápověda je krátká věta, kterou student může v té chvíli opravdu říct, a nevymýšlí si o něm fakta.
Pokud režisér dostal kartičky (výrazy, které se student učí), smí jednu vplést jen tehdy, když přirozeně sedí k tomu, o čem se právě mluví. Rada pak tutora navede k otázce nebo situaci, ve které student výraz řekne sám, a výraz sama neobsahuje. Kvůli kartičce nesmí měnit živé téma ani z hovoru dělat zkoušení slovíček. Když žádná kartička nesedí, je správně žádnou nevplést. Po opravě a při loučení kartička nepatří.
Posuzuj, zda je výstup režiséra v této chvíli vhodný podle těchto pravidel.''';
