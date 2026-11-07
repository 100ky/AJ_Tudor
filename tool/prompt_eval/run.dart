// Test systémového promptu hlasového tutora na skutečných replikách z lekcí.
//
// Každý případ pošle živému modelu (gemini-3.8-live) skutečnou historii lekce
// a jednu repliku studenta a vyhodnotí jeho odpověď: automatické kontroly
// (checks.dart) a rozhodčí model podle očekávaného chování z případu.
//
//   dart run tool/prompt_eval/run.dart --dry-run                       (jen plán a odhad spotřeby)
//   dart run tool/prompt_eval/run.dart --label baseline --max-requests 120 [--runs 2] [--only 19-568,2-40] [--no-judge] [--resume]
//   dart run tool/prompt_eval/run.dart --label candidate --judge-only --model gemini-3.6-flash --max-requests 100
//                                          (ohodnotí uložené odpovědi rozhodčím)
//   dart run tool/prompt_eval/run.dart --compare baseline candidate
//
// Klíč se čte z proměnné prostředí GEMINI_API_KEY. Případy i výsledky obsahují
// repliky z lekcí, proto jsou ve složce private/, kterou git ignoruje.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/core/constants/gemini_models.dart';
import 'package:aj_tudor/services/prompt/live_tutor_prompts.dart';
import 'package:aj_tudor/data/models/error_category.dart';
import 'package:aj_tudor/services/flashcards/conversation_cards.dart';
import 'package:aj_tudor/services/prompt/system_prompt_builder.dart';

import 'checks.dart';
import 'common.dart';

Future<void> main(List<String> args) async {
  final options = EvalOptions.parse(args, defaultLabel: 'baseline');
  if (options.compare != null) {
    await compareRuns(options.compare!.$1, options.compare!.$2);
    return;
  }
  final casesFile = options.casesFile != null
      ? File(options.casesFile!)
      : File.fromUri(privateDir.resolve('cases.json'));
  final data = jsonDecode(await casesFile.readAsString())
      as Map<String, dynamic>;
  final profile = data['profile'] as Map<String, dynamic>;
  final promptFile = options.promptFile;
  final fixedPrompt = promptFile != null ? await File(promptFile).readAsString() : null;
  // Případy lekce mají vlastní seznam výrazů, prompt i úvod se sestaví jako v aplikaci
  String promptFor(Map<String, dynamic> testCase) =>
      fixedPrompt ??
      SystemPromptBuilder.buildTutorPrompt(
        targetLevel: profile['targetLevel'] as String? ?? 'B1',
        recurringErrors: profile['recurringErrors'] as String?,
        vocabulary: profile['vocabulary'] as String?,
        recentTopics: profile['topicPreferences'] as String?,
        memoryBriefing: profile['memoryBriefing'] as String?,
        userFacts: profile['userFacts'] as String?,
        lessonCards: _lessonCards(testCase),
        grammarGoal: ErrorCategory.parse(testCase['grammarGoal'] as String?),
      );
  String openingFor(Map<String, dynamic> testCase) => LiveTutorPrompts.opening(
        briefing: profile['memoryBriefing'] as String?,
        lesson: _lessonCards(testCase).isNotEmpty,
      );
  // Prompt běžného hovoru (bez lekce) pro výpis a hlášení
  final systemPrompt = promptFor(const {});

  final cases = (data['cases'] as List)
      .cast<Map<String, dynamic>>()
      .where((c) => options.only.isEmpty || options.only.contains(c['id']))
      .toList();

  if (options.judgeOnly) {
    final apiKey = apiKeyFromEnvironment();
    if (apiKey == null) return;
    RequestBudget.start(options.maxRequests);
    final byId = {for (final c in cases) c['id']: c};
    if (options.recheck) await _recheckSaved(options.label, byId);
    await judgeSavedReplies(
      apiKey: apiKey,
      options: options,
      rules: _judgeRules,
      question: (resultCase, reply) =>
          _judgeQuestion(byId[resultCase['id']]!, reply['text'] as String),
    );
    return;
  }
  stdout.writeln('Prompt: ${systemPrompt.length} znaků, případů: ${cases.length}, opakování: ${options.runs}');

  final results = options.resume ? loadFinishedCases(options.label, runs: options.runs) : <Map<String, dynamic>>[];
  final finished = {for (final c in results) c['id']};
  final pending = cases.where((c) => !finished.contains(c['id'])).toList();

  if (options.dryRun) {
    var requestChars = 0;
    var judgeChars = 0;
    for (final c in pending) {
      final history = (c['history'] as List).cast<Map<String, dynamic>>();
      requestChars += promptFor(c).length + openingFor(c).length + (c['student'] as String).length;
      requestChars += history.fold(0, (sum, t) => sum + (t['text'] as String).length);
      final recentSix = history.length > 6 ? history.sublist(history.length - 6) : history;
      // Otázka pro rozhodčího: konec rozhovoru, odpověď tutora (~300 znaků) a očekávání
      judgeChars += _judgeRules.length + transcriptOf(recentSix).length + (c['expect'] as String).length + 300;
    }
    printDryRun(
      agent: 'tutor',
      model: GeminiModels.defaultLiveModel,
      cases: pending.length,
      runs: options.runs,
      judge: options.judge,
      requestChars: requestChars,
      judgeChars: judgeChars,
    );
    return;
  }
  final apiKey = apiKeyFromEnvironment();
  if (apiKey == null) return;
  RequestBudget.start(options.maxRequests);
  Map<String, Object?> report() => {
        'label': options.label,
        'agent': 'tutor',
        'date': DateTime.now().toIso8601String(),
        'promptChars': systemPrompt.length,
        'promptFile': promptFile,
        'runs': options.runs,
        'judge': options.judge,
        'cases': results,
      };

  try {
    for (final testCase in pending) {
      results.add(await _runCase(apiKey, promptFor(testCase), openingFor(testCase), testCase, options));
      // Průběžné uložení: přerušený běh jde navázat přes --resume
      await saveReport(report());
    }
  } on StopRun catch (e) {
    stdout.writeln('\n⛔ $e. Test končí, hotové případy jsou uložené (pokračování: --resume).');
    exitCode = 3;
  }
  await saveReport(report(), announce: true);
  stdout.writeln('Požadavků na API v tomto běhu: ${RequestBudget.used} z ${options.maxRequests}');
}

Future<Map<String, Object?>> _runCase(
  String apiKey,
  String systemPrompt,
  String opening,
  Map<String, dynamic> testCase,
  EvalOptions options,
) async {
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final student = testCase['student'] as String;
  final turns = _turns(opening, history, student);
  final replies = <Map<String, Object?>>[];

  for (var run = 1; run <= options.runs; run++) {
    String reply;
    try {
      reply = await withRetry(() => _askTutor(apiKey, systemPrompt, turns));
    } on StopRun {
      rethrow;
    } catch (e) {
      stdout.writeln('${testCase['id']} [$run] ⚠️ tutor neodpověděl: $e');
      replies.add({'error': e.toString()});
      continue;
    }
    final checks = _checksFor(testCase, reply);
    Map<String, Object?>? verdict;
    // Rozhodčí jen u odpovědí, které prošly automatickými kontrolami: jinak neprošla tak jako tak
    if (options.judge && checks.every((c) => c.passed)) {
      await Future<void>.delayed(requestPause);
      verdict = await judge(
        apiKey,
        rules: _judgeRules,
        question: _judgeQuestion(testCase, reply),
        models: options.judgeModels,
      );
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

/// Automatické kontroly odpovědi [reply] tutora v případu [testCase].
List<ReplyCheck> _checksFor(Map<String, dynamic> testCase, String reply) {
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final student = testCase['student'] as String;
  final recent = history.length > 4 ? history.sublist(history.length - 4) : history;
  return checkReply(
    CaseKind.parse(testCase['kind'] as String),
    reply,
    earlierTutorLines: [
      for (final turn in history)
        if (turn['role'] == 'model') turn['text'] as String,
    ],
    recentContext: [...recent.map((t) => t['text'] as String), student].join('\n'),
    lessonTarget: _lessonTarget(testCase),
  );
}

/// Přepočítá kontroly uložených odpovědí běhu [label] podle aktuálních pravidel.
/// Odpověď, která nově prošla, přijde o starý výsledek a ohodnotí ji rozhodčí.
Future<void> _recheckSaved(String label, Map<Object?, Map<String, dynamic>> byId) async {
  final file = File.fromUri(privateDir.resolve('results/$label.json'));
  final report = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  var changed = 0;
  for (final result in (report['cases'] as List).cast<Map<String, dynamic>>()) {
    final testCase = byId[result['id']];
    if (testCase == null) continue;
    for (final reply in (result['replies'] as List).cast<Map<String, dynamic>>()) {
      final text = reply['text'] as String?;
      if (text == null) continue;
      final checks = _checksFor(testCase, text);
      final allPassed = checks.every((c) => c.passed);
      final before = (reply['checks'] as List).cast<Map<String, dynamic>>().every((c) => c['passed'] == true);
      reply['checks'] = [for (final c in checks) c.toJson()];
      if (allPassed != before) changed++;
      if (!allPassed) {
        reply['passed'] = false;
      } else if (!before) {
        reply['judge'] = null;
        reply['passed'] = null;
      }
    }
  }
  await saveReport(report);
  stdout.writeln('Kontroly přepočítány, změnilo se odpovědí: $changed');
}

/// Výrazy lekce z případu (prázdné u běžného hovoru).
List<ConversationCard> _lessonCards(Map<String, dynamic> testCase) => [
      for (final card in (testCase['lessonCards'] as List? ?? const []).cast<Map<String, dynamic>>())
        ConversationCard(id: card['id'] as int, czech: card['czech'] as String, english: card['english'] as String),
    ];

/// Výraz, který má tutor v případu lekce uvést nebo říct (pořadí ve [_lessonCards]).
ConversationCard? _lessonTarget(Map<String, dynamic> testCase) {
  final index = testCase['lessonTarget'] as int?;
  final cards = _lessonCards(testCase);
  return index == null || index >= cards.length ? null : cards[index];
}

/// Otázka pro rozhodčího: konec rozhovoru, odpověď tutora a očekávané chování z případu.
String _judgeQuestion(Map<String, dynamic> testCase, String reply) {
  final history = (testCase['history'] as List).cast<Map<String, dynamic>>();
  final recentSix = history.length > 6 ? history.sublist(history.length - 6) : history;
  final lesson = _lessonCards(testCase);
  final lessonText = lesson.isEmpty
      ? ''
      : 'Režim lekce, výrazy v pořadí:\n${[for (var i = 0; i < lesson.length; i++) '${i + 1}. ${lesson[i].czech} → ${lesson[i].english}'].join('\n')}\n\n';
  final student = testCase['student'] as String;
  return '''${lessonText}Konec rozhovoru:
${recentSix.isEmpty ? '(začátek hovoru)' : transcriptOf(recentSix)}
${student.isEmpty ? '' : 'Student: $student'}

Odpověď tutora: $reply

Očekávané chování: ${testCase['expect']}

Splňuje odpověď tutora očekávané chování? Vrať pass a zdůvodnění (jedna věta česky).''';
}

const String _judgeRules = '''Jsi přísný, ale férový hodnotitel odpovědí AI tutora angličtiny pro českého studenta (úroveň B1).
Pravidla tutora: skutečné chyby (čas, vazba, slovíčko, české slovo) opravuje česky, v tahu s opravou nepokládá otázku k tématu a skončí výzvou k zopakování. Drobnosti (člen, množné číslo) neopravuje. Předložky at/on/in opravuje (student si to přeje), ale až po čase a tvaru slovesa. Z jedné promluvy opraví v jednom tahu nejvýš jednu chybu. Měla-li promluva druhou významnou chybu, po zopakování první opravy pochválí a vrátí se k té druhé, jinak pochválí a vrátí se k tématu jednou otázkou. Neodbočuje k jídlu, vaření ani koníčkům, pokud o nich řeč není, a neklade otázky, které už v lekci položil. Když student přemýšlí (uh, um), počká. Na českou větu nebo „jak se řekne“ dá anglickou verzi bez „Pozor, v angličtině neříkáme“ a nemění téma. Nesrozumitelný přepis nechá zopakovat a nic si nedomýšlí. V jednom tahu klade nejvýš jednu otázku a mimo opravy mluví krátce.
V režimu lekce (případ uvádí výrazy lekce) tutor provádí studenta výrazy z jeho kartiček: ke každému dá krátkou situaci nebo otázku, anglický výraz neříká první, když ho student nepoužije, napoví českou stranou kartičky, a když ani pak, řekne mu ho a nechá ho zopakovat. Po správném výrazu pochválí a v tomtéž tahu uvede další. Po posledním výrazu nebo po vypršení času lekci česky uzavře a nabídne volný pokec. Skryté zprávy „[SYSTEM INSTRUCTION …] Lekce: …“ jsou pokyny aplikace, ne slova studenta.
Odpověď tutora je přepis jeho řeči, drobné chyby přepisu ignoruj. Posuzuj jen, zda odpověď splňuje OČEKÁVANÉ CHOVÁNÍ uvedené u případu.''';

/// Úvodní skrytá zpráva, historie lekce a replika studenta jako tahy clientContent.
/// Po sobě jdoucí repliky stejné strany se spojí do jednoho tahu.
List<Map<String, Object>> _turns(String opening, List<Map<String, dynamic>> history, String student) {
  final merged = <({String role, String text})>[(role: 'user', text: opening)];
  for (final turn in [...history, if (student.isNotEmpty) {'role': 'user', 'text': student}]) {
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
  RequestBudget.take();
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
