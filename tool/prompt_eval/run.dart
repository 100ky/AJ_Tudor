// Test systémového promptu hlasového tutora na skutečných replikách z lekcí.
//
// Každý případ pošle živému modelu (gemini-3.8-live) skutečnou historii lekce
// a jednu repliku studenta a vyhodnotí jeho odpověď: automatické kontroly
// (checks.dart) a rozhodčí model podle očekávaného chování z případu.
//
//   dart run tool/prompt_eval/run.dart --label baseline [--runs 3] [--only 19-568,2-40] [--no-judge] [--resume]
//   dart run tool/prompt_eval/run.dart --compare baseline candidate
//
// Klíč se čte z proměnné prostředí GEMINI_API_KEY. Případy i výsledky obsahují
// repliky z lekcí, proto jsou ve složce private/, kterou git ignoruje.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/services/prompt/live_tutor_prompts.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

import 'checks.dart';
import 'common.dart';

Future<void> main(List<String> args) async {
  final options = EvalOptions.parse(args, defaultLabel: 'baseline');
  if (options.compare != null) {
    await compareRuns(options.compare!.$1, options.compare!.$2);
    return;
  }
  final apiKey = apiKeyFromEnvironment();
  if (apiKey == null) return;

  final data = jsonDecode(await File.fromUri(privateDir.resolve('cases.json')).readAsString())
      as Map<String, dynamic>;
  final profile = data['profile'] as Map<String, dynamic>;
  final systemPrompt = SystemPromptBuilder.buildTutorPrompt(
    targetLevel: profile['targetLevel'] as String? ?? 'B1',
    recurringErrors: profile['recurringErrors'] as String?,
    vocabulary: profile['vocabulary'] as String?,
    recentTopics: profile['topicPreferences'] as String?,
    memoryBriefing: profile['memoryBriefing'] as String?,
    userFacts: profile['userFacts'] as String?,
  );
  final opening = LiveTutorPrompts.opening(briefing: profile['memoryBriefing'] as String?);

  final cases = (data['cases'] as List)
      .cast<Map<String, dynamic>>()
      .where((c) => options.only.isEmpty || options.only.contains(c['id']))
      .toList();
  stdout.writeln('Prompt: ${systemPrompt.length} znaků, případů: ${cases.length}, opakování: ${options.runs}');

  final results = options.resume ? loadFinishedCases(options.label) : <Map<String, dynamic>>[];
  final finished = {for (final c in results) c['id']};
  Map<String, Object?> report() => {
        'label': options.label,
        'agent': 'tutor',
        'date': DateTime.now().toIso8601String(),
        'promptChars': systemPrompt.length,
        'runs': options.runs,
        'judge': options.judge,
        'cases': results,
      };

  try {
    for (final testCase in cases.where((c) => !finished.contains(c['id']))) {
      results.add(await _runCase(apiKey, systemPrompt, opening, testCase, options));
      // Průběžné uložení: přerušený běh jde navázat přes --resume
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
  String systemPrompt,
  String opening,
  Map<String, dynamic> testCase,
  EvalOptions options,
) async {
  final kind = CaseKind.parse(testCase['kind'] as String);
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final student = testCase['student'] as String;
  final turns = _turns(opening, history, student);
  final earlierTutorLines = [
    for (final turn in history)
      if (turn['role'] == 'model') turn['text'] as String,
  ];
  final recent = history.length > 4 ? history.sublist(history.length - 4) : history;
  final recentContext = [...recent.map((t) => t['text'] as String), student].join('\n');
  final replies = <Map<String, Object?>>[];

  for (var run = 1; run <= options.runs; run++) {
    String reply;
    try {
      reply = await withRetry(() => _askTutor(apiKey, systemPrompt, turns));
    } on QuotaExceeded {
      rethrow;
    } catch (e) {
      stdout.writeln('${testCase['id']} [$run] ⚠️ tutor neodpověděl: $e');
      replies.add({'error': e.toString()});
      continue;
    }
    final checks = checkReply(kind, reply, earlierTutorLines: earlierTutorLines, recentContext: recentContext);
    Map<String, Object?>? verdict;
    if (options.judge) {
      await Future<void>.delayed(requestPause);
      final recentSix = history.length > 6 ? history.sublist(history.length - 6) : history;
      verdict = await judge(apiKey, rules: _judgeRules, question: '''Konec rozhovoru:
${transcriptOf(recentSix)}
Student: $student

Odpověď tutora: $reply

Očekávané chování: ${testCase['expect']}

Splňuje odpověď tutora očekávané chování? Vrať pass a zdůvodnění (jedna věta česky).''');
    }
    final passed = replyPassed(checks.map((c) => c.passed), verdict);
    replies.add({
      'text': reply,
      'checks': [for (final c in checks) c.toJson()],
      'judge': verdict,
      'passed': passed,
    });
    final failed = checks.where((c) => !c.passed).map((c) => c.name).join(', ');
    stdout.writeln('${testCase['id']} [$run] ${switch (passed) { true => '✓', false => '✗', _ => '?' }} '
        '${failed.isEmpty ? '' : '($failed) '}${verdict != null && verdict['pass'] != true ? '— ${verdict['reason']}' : ''}');
    await Future<void>.delayed(requestPause);
  }

  return {
    'id': testCase['id'],
    'kind': testCase['kind'],
    'student': student,
    'expect': testCase['expect'],
    'replies': replies,
  };
}

const String _judgeRules = '''Jsi přísný, ale férový hodnotitel odpovědí AI tutora angličtiny pro českého studenta (úroveň B1).
Pravidla tutora: skutečné chyby (čas, vazba, slovíčko, české slovo) opravuje česky, v tahu s opravou nepokládá otázku k tématu a skončí výzvou k zopakování. Drobnosti (člen, drobnou předložku, množné číslo) neopravuje. Z jedné promluvy opraví v jednom tahu nejvýš jednu chybu. Měla-li promluva druhou významnou chybu, po zopakování první opravy pochválí a vrátí se k té druhé, jinak pochválí a vrátí se k tématu jednou otázkou. Neodbočuje k jídlu, vaření ani koníčkům, pokud o nich řeč není, a neklade otázky, které už v lekci položil. Když student přemýšlí (uh, um), počká. Na českou větu nebo „jak se řekne“ dá anglickou verzi bez „Pozor, v angličtině neříkáme“ a nemění téma. Nesrozumitelný přepis nechá zopakovat a nic si nedomýšlí. V jednom tahu klade nejvýš jednu otázku a mimo opravy mluví krátce.
Odpověď tutora je přepis jeho řeči, drobné chyby přepisu ignoruj. Posuzuj jen, zda odpověď splňuje OČEKÁVANÉ CHOVÁNÍ uvedené u případu.''';

/// Úvodní skrytá zpráva, historie lekce a replika studenta jako tahy clientContent.
/// Po sobě jdoucí repliky stejné strany se spojí do jednoho tahu.
List<Map<String, Object>> _turns(String opening, List<Map<String, dynamic>> history, String student) {
  final merged = <({String role, String text})>[(role: 'user', text: opening)];
  for (final turn in [...history, {'role': 'user', 'text': student}]) {
    final role = turn['role'] as String;
    final text = turn['text'] as String;
    if (merged.last.role == role) {
      merged[merged.length - 1] = (role: role, text: '${merged.last.text}\n$text');
    } else {
      merged.add((role: role, text: text));
    }
  }
  return [
    for (final turn in merged)
      {
        'role': turn.role,
        'parts': [
          {'text': turn.text}
        ],
      }
  ];
}

/// Jeden živý hovor: stejný setup jako aplikace, historie jako clientContent,
/// odpověď tutora z přepisu jeho řeči (outputTranscription).
Future<String> _askTutor(String apiKey, String systemPrompt, List<Map<String, Object>> turns) async {
  final socket = await WebSocket.connect(
    'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey',
  ).timeout(const Duration(seconds: 15));
  final transcript = StringBuffer();
  final setupDone = Completer<void>();
  final turnDone = Completer<void>();

  // Chyba po zavření spojení nesmí shodit test jako neošetřená (čeká se jen na jeden z nich)
  setupDone.future.ignore();
  turnDone.future.ignore();

  void fail(Object error) {
    if (!setupDone.isCompleted) setupDone.completeError(error);
    if (!turnDone.isCompleted) turnDone.completeError(error);
  }

  final subscription = socket.listen(
    (message) {
      final raw = message is String ? message : utf8.decode(message as List<int>);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('setupComplete') && !setupDone.isCompleted) setupDone.complete();
      if (data['error'] != null) fail(StateError('Chyba serveru: ${data['error']}'));
      final content = data['serverContent'];
      if (content is Map) {
        final output = content['outputTranscription'];
        if (output is Map && output['text'] is String) transcript.write(output['text']);
        if (content['turnComplete'] == true && !turnDone.isCompleted) turnDone.complete();
      }
    },
    onError: fail,
    onDone: () {
      final reason = socket.closeReason ?? '';
      fail(isQuotaMessage(reason)
          ? QuotaExceeded('Live API: $reason')
          : StateError('Spojení zavřeno (${socket.closeCode} $reason)'));
    },
  );

  try {
    socket.add(jsonEncode({
      'setup': {
        'model': 'models/${GeminiModels.defaultLiveModel}',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Puck'}
            }
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'inputAudioTranscription': <String, Object>{},
        'outputAudioTranscription': <String, Object>{},
        'realtimeInputConfig': {
          'automaticActivityDetection': {'disabled': true},
          'activityHandling': 'START_OF_ACTIVITY_INTERRUPTS',
          'turnCoverage': 'TURN_INCLUDES_ONLY_ACTIVITY',
        },
      }
    }));
    await setupDone.future.timeout(const Duration(seconds: 20));
    socket.add(jsonEncode({
      'clientContent': {'turns': turns, 'turnComplete': true}
    }));
    await turnDone.future.timeout(const Duration(seconds: 60));
  } finally {
    await subscription.cancel();
    await socket.close();
  }
  return transcript.toString().replaceAll(RegExp('<' r'ctrl\d+>'), '').trim();
}
