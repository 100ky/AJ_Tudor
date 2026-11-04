/// Společné části testů promptů: volání Gemini, uložení výsledků, souhrn a porovnání.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aj_tudor/core/constants/gemini_models.dart';

/// Složka s případy a výsledky (git ji ignoruje, obsahuje repliky z lekcí).
final Uri privateDir = Platform.script.resolve('private/');

/// Modely pro rozhodčího a režiséra v pořadí, v jakém se zkoušejí při přetížení.
const List<String> textModels = [GeminiModels.flash3_8, GeminiModels.flash3_6, GeminiModels.flashLite3_5];

/// API klíč z proměnné prostředí; null, když chybí.
String? apiKeyFromEnvironment() {
  final key = Platform.environment['GEMINI_API_KEY']?.trim() ?? '';
  if (key.isNotEmpty) return key;
  stderr.writeln('Chybí proměnná prostředí GEMINI_API_KEY.');
  exitCode = 2;
  return null;
}

/// Kvóta API klíče je vyčerpaná. Test se zastaví a dosavadní výsledky zůstanou uložené,
/// aby nespotřeboval limit, který potřebuje i aplikace (bezplatná úroveň).
class QuotaExceeded implements Exception {
  QuotaExceeded(this.detail);

  final String detail;

  @override
  String toString() => 'Vyčerpaná kvóta API klíče ($detail)';
}

/// Zda chybová odpověď API hlásí vyčerpanou kvótu.
bool isQuotaMessage(String text) =>
    text.contains('exceeded your current quota') || text.contains('RESOURCE_EXHAUSTED');

/// Odstup mezi požadavky, aby test nenarazil na minutové limity bezplatné úrovně.
const Duration requestPause = Duration(seconds: 4);

/// Volání `generateContent` přes REST.
Future<Map<String, dynamic>> generateContent(String apiKey, String model, Map<String, Object?> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'));
    request.headers
      ..set('x-goog-api-key', apiKey)
      ..contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(const Duration(seconds: 60));
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode == 429 && isQuotaMessage(text)) {
      throw QuotaExceeded('HTTP 429 od $model');
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} od $model');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

/// Strukturovaná odpověď (JSON podle [schema]) z prvního modelu, který odpoví.
Future<(Map<String, dynamic>, String)> generateJson(
  String apiKey, {
  required String systemPrompt,
  required String userText,
  required Map<String, Object?> schema,
  List<String> models = textModels,
}) async {
  Object? lastError;
  var allQuota = true;
  for (final model in models) {
    try {
      final data = await generateContent(apiKey, model, {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userText}
            ]
          }
        ],
        'generationConfig': {'responseMimeType': 'application/json', 'responseSchema': schema},
      });
      final parts = (data['candidates'] as List).first['content']['parts'] as List;
      final text = parts.map((p) => p['text'] ?? '').join();
      return (jsonDecode(text) as Map<String, dynamic>, model);
    } catch (e) {
      // Kvóta se počítá pro každý model zvlášť: záložní model ještě může odpovědět
      lastError = e;
      if (e is! QuotaExceeded) allQuota = false;
    }
  }
  if (allQuota) throw QuotaExceeded('všechny modely: $lastError');
  throw StateError('Žádný model neodpověděl: $lastError');
}

const Map<String, Object?> _verdictSchema = {
  'type': 'object',
  'properties': {
    'pass': {'type': 'boolean'},
    'reason': {'type': 'string'},
  },
  'required': ['pass', 'reason'],
};

/// Posouzení rozhodčím modelem: `{pass, reason, model}`, nebo `{pass: null, reason: chyba}`
/// (odpověď pak zůstane nehodnocená). Vyčerpaná kvóta test zastaví ([QuotaExceeded]).
Future<Map<String, Object?>> judge(String apiKey, {required String rules, required String question}) async {
  try {
    final (verdict, model) = await generateJson(apiKey, systemPrompt: rules, userText: question, schema: _verdictSchema);
    return {'pass': verdict['pass'] == true, 'reason': verdict['reason'], 'model': model};
  } on QuotaExceeded {
    rethrow;
  } catch (e) {
    return {'pass': null, 'reason': 'Rozhodčí selhal: $e'};
  }
}

/// Výsledek odpovědi: prošla (true), neprošla (false), nebo je nehodnocená (null),
/// když rozhodčí neodpověděl.
bool? replyPassed(Iterable<bool> checks, Map<String, Object?>? verdict) {
  if (checks.any((passed) => !passed)) return false;
  if (verdict == null) return true;
  final pass = verdict['pass'];
  return pass is bool ? pass : null;
}

/// Přetížené API občas spojení odmítne nebo zavře: zkusí to ještě dvakrát.
/// Vyčerpanou kvótu znovu nezkouší.
Future<T> withRetry<T>(Future<T> Function() action) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (e is QuotaExceeded || attempt >= 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 3 * attempt));
    }
  }
}

/// Text posledních replik pro rozhodčího.
String transcriptOf(List<Map<String, dynamic>> turns, {String tutorName = 'Tutor'}) =>
    turns.map((t) => '${t['role'] == 'user' ? 'Student' : tutorName}: ${t['text']}').join('\n');

// ─── Výsledky ──────────────────────────────────────────────────────────────

/// Uloží výsledky běhu jako JSON i čitelný přehled. Volá se po každém případu,
/// aby přerušený běh nepřišel o hotové výsledky; s [announce] vypíše souhrn.
Future<void> saveReport(Map<String, Object?> report, {bool announce = false}) async {
  final resultsDir = Directory.fromUri(privateDir.resolve('results/'))..createSync(recursive: true);
  final label = report['label'];
  await File('${resultsDir.path}$label.json').writeAsString(const JsonEncoder.withIndent(' ').convert(report));
  await File('${resultsDir.path}$label.md').writeAsString(_markdown(report));
  if (!announce) return;
  stdout.writeln();
  stdout.write(summaryOf(report));
  stdout.writeln('Výsledky: ${resultsDir.path}$label.json a .md');
}

/// Hotové případy z dřívějšího běhu [label] (pro `--resume`); prázdné, když běh neexistuje.
List<Map<String, dynamic>> loadFinishedCases(String label) {
  final file = File.fromUri(privateDir.resolve('results/$label.json'));
  if (!file.existsSync()) return [];
  final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (report['cases'] as List).cast<Map<String, dynamic>>();
}

/// Úspěšnost odpovědí podle druhu případu: druh → (prošlo, celkem).
/// Odpovědi bez výsledku (chyba, nehodnocené rozhodčím) se nepočítají.
Map<String, (int, int)> passRates(Map<String, dynamic> report) {
  final rates = <String, (int, int)>{};
  for (final c in (report['cases'] as List).cast<Map<String, dynamic>>()) {
    for (final r in (c['replies'] as List).cast<Map<String, dynamic>>()) {
      if (r.containsKey('error') || r['passed'] == null) continue;
      final kind = c['kind'] as String;
      final (passed, total) = rates[kind] ?? (0, 0);
      rates[kind] = (passed + (r['passed'] == true ? 1 : 0), total + 1);
    }
  }
  return rates;
}

String _percent((int, int) rate) =>
    rate.$2 == 0 ? '–' : '${(100 * rate.$1 / rate.$2).round()} % (${rate.$1}/${rate.$2})';

/// Úspěšnost jednotlivých kontrol napříč všemi odpověďmi: název → (prošlo, celkem).
Map<String, (int, int)> checkRates(Map<String, dynamic> report) {
  final rates = <String, (int, int)>{};
  for (final c in (report['cases'] as List).cast<Map<String, dynamic>>()) {
    for (final r in (c['replies'] as List).cast<Map<String, dynamic>>()) {
      final judged = r['judge'] as Map<String, dynamic>?;
      for (final check in [
        ...((r['checks'] as List?) ?? const []).cast<Map<String, dynamic>>(),
        if (judged != null && judged['pass'] != null) {'name': 'rozhodčí', 'passed': judged['pass']},
      ]) {
        final name = check['name'] as String;
        final (passed, total) = rates[name] ?? (0, 0);
        rates[name] = (passed + (check['passed'] == true ? 1 : 0), total + 1);
      }
    }
  }
  return rates;
}

String summaryOf(Map<String, dynamic> report) {
  final rates = passRates(report);
  final all = rates.values.fold((0, 0), (sum, r) => (sum.$1 + r.$1, sum.$2 + r.$2));
  final buffer = StringBuffer('Úspěšnost (${report['label']}):\n');
  for (final entry in rates.entries) {
    buffer.writeln('  ${entry.key.padRight(14)} ${_percent(entry.value)}');
  }
  buffer.writeln('  ${'celkem'.padRight(14)} ${_percent(all)}\nKontroly:');
  for (final entry in checkRates(report).entries) {
    buffer.writeln('  ${entry.key.padRight(40)} ${_percent(entry.value)}');
  }
  return buffer.toString();
}

String _markdown(Map<String, dynamic> report) {
  final buffer = StringBuffer('# Test promptu: ${report['label']} (${report['date']})\n\n```\n${summaryOf(report)}```\n');
  for (final c in (report['cases'] as List).cast<Map<String, dynamic>>()) {
    buffer.writeln('\n## ${c['id']} (${c['kind']})\n\n**Student:** ${c['student']}\n\n**Očekává se:** ${c['expect']}\n');
    for (final r in (c['replies'] as List).cast<Map<String, dynamic>>()) {
      if (r.containsKey('error')) {
        buffer.writeln('- ⚠️ ${r['error']}');
        continue;
      }
      final failed = (r['checks'] as List).where((x) => x['passed'] != true).map((x) => x['name']).join(', ');
      final judged = r['judge'] as Map<String, dynamic>?;
      buffer.writeln('- ${switch (r['passed']) { true => '✓', false => '✗', _ => '?' }} ${r['text']}');
      if (failed.isNotEmpty) buffer.writeln('  - kontroly: $failed');
      if (judged != null) buffer.writeln('  - rozhodčí: ${judged['pass'] == true ? 'ano' : 'ne'}, ${judged['reason']}');
    }
  }
  return buffer.toString();
}

/// Porovná dva uložené běhy podle druhu případu, kontrol i jednotlivých případů.
Future<void> compareRuns(String a, String b) async {
  Future<Map<String, dynamic>> load(String label) async =>
      jsonDecode(await File.fromUri(privateDir.resolve('results/$label.json')).readAsString())
          as Map<String, dynamic>;
  final first = await load(a);
  final second = await load(b);

  void table(String title, Map<String, (int, int)> ratesA, Map<String, (int, int)> ratesB, int width) {
    stdout.writeln('${title.padRight(width)} ${a.padRight(18)} $b');
    for (final key in {...ratesA.keys, ...ratesB.keys}) {
      stdout.writeln('${key.padRight(width)} ${_percent(ratesA[key] ?? (0, 0)).padRight(18)} ${_percent(ratesB[key] ?? (0, 0))}');
    }
  }

  table('druh', passRates(first), passRates(second), 14);
  stdout.writeln();
  table('kontrola', checkRates(first), checkRates(second), 40);

  Map<String, double> perCase(Map<String, dynamic> report) => {
        for (final c in (report['cases'] as List).cast<Map<String, dynamic>>())
          c['id'] as String: () {
            final replies = (c['replies'] as List)
                .cast<Map<String, dynamic>>()
                .where((r) => !r.containsKey('error') && r['passed'] != null);
            return replies.isEmpty ? 0.0 : replies.where((r) => r['passed'] == true).length / replies.length;
          }(),
      };
  final caseA = perCase(first);
  final caseB = perCase(second);
  stdout.writeln('\nPřípady, které se změnily:');
  for (final id in caseA.keys.where(caseB.containsKey)) {
    final before = caseA[id]!;
    final after = caseB[id]!;
    if (before != after) {
      stdout.writeln('  $id: ${(100 * before).round()} % → ${(100 * after).round()} % ${after > before ? '↑' : '↓'}');
    }
  }
}

/// Přepínače příkazové řádky obou testů.
class EvalOptions {
  EvalOptions({
    required this.label,
    required this.runs,
    required this.only,
    required this.judge,
    required this.resume,
    this.compare,
  });

  final String label;
  final int runs;
  final Set<String> only;
  final bool judge;

  /// Navázat na přerušený běh stejného názvu: hotové případy se přeskočí.
  final bool resume;
  final (String, String)? compare;

  static EvalOptions parse(List<String> args, {required String defaultLabel}) {
    var label = defaultLabel;
    var runs = 3;
    var only = <String>{};
    var judge = true;
    var resume = false;
    (String, String)? compare;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--label':
          label = args[++i];
        case '--runs':
          runs = int.parse(args[++i]);
        case '--only':
          only = args[++i].split(',').map((s) => s.trim()).toSet();
        case '--no-judge':
          judge = false;
        case '--resume':
          resume = true;
        case '--compare':
          compare = (args[++i], args[++i]);
        default:
          throw ArgumentError('Neznámý přepínač: ${args[i]}');
      }
    }
    return EvalOptions(label: label, runs: runs, only: only, judge: judge, resume: resume, compare: compare);
  }
}
