// Test rozhodčího kartiček v lekci (LessonCardJudge): u replik studenta, u kterých je jasné,
// jestli kartičku splňují, zjistí, jestli flash-lite rozhodne stejně.
//
//   dart run tool/prompt_eval/lesson_judge.dart --dry-run
//   dart run tool/prompt_eval/lesson_judge.dart --label judge-lekce --max-requests 12
//
// Případy jsou v private/lesson_judge_cases.json: {"cards": [{id, czech, english}],
// "cases": [{"id", "tutor": [...], "student", "expect": id nebo 0, "why"}]}.
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

import 'common.dart';

Future<void> main(List<String> args) async {
  final options = EvalOptions.parse(args, defaultLabel: 'judge-lekce');
  final data = jsonDecode(await File.fromUri(privateDir.resolve('lesson_judge_cases.json')).readAsString())
      as Map<String, dynamic>;
  final cards = [
    for (final c in (data['cards'] as List).cast<Map<String, dynamic>>())
      ConversationCard(id: c['id'] as int, czech: c['czech'] as String, english: c['english'] as String),
  ];
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();
  final model = options.model ?? GeminiModels.flashLite3_5;
  if (options.dryRun) {
    stdout.writeln('Plán: ${cases.length} replik × 1 volání modelu $model, nic se neposílá.');
    return;
  }
  final apiKey = apiKeyFromEnvironment();
  if (apiKey == null) return;
  RequestBudget.start(options.maxRequests);

  var agreed = 0;
  final results = <Map<String, Object?>>[];
  try {
    for (final c in cases) {
      final (output, _) = await generateJson(
        apiKey,
        systemPrompt: SystemPromptBuilder.lessonJudgeSystem,
        userText: SystemPromptBuilder.buildLessonJudgeRequest(
          cards: cards,
          recentTutorLines: (c['tutor'] as List).cast<String>(),
          studentText: c['student'] as String,
        ),
        schema: SystemPromptBuilder.getLessonJudgeSchema(),
        models: [model],
      );
      final got = (output['cardId'] as num?)?.toInt() ?? 0;
      final ok = got == c['expect'];
      if (ok) agreed++;
      stdout.writeln('${c['id']} ${ok ? '✓' : '✗'} čekáno ${c['expect']}, rozhodčí $got — ${output['reason']}');
      results.add({'id': c['id'], 'expect': c['expect'], 'got': got, 'reason': output['reason'], 'ok': ok});
      await Future<void>.delayed(requestPause);
    }
  } on StopRun catch (e) {
    stdout.writeln('\n⛔ $e');
    exitCode = 3;
  }
  stdout.writeln('\nShoda: $agreed z ${results.length}. Požadavků: ${RequestBudget.used}');
  final out = File.fromUri(privateDir.resolve('results/${options.label}.json'));
  await out.writeAsString(const JsonEncoder.withIndent(' ').convert({'model': model, 'results': results}));
}
