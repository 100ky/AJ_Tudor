import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pravidla struktury z README (oddíl „Pravidla struktury“) jako test, aby je nebylo
/// potřeba před každým commitem pouštět ručně.
void main() {
  /// Vrstvy od nejnižší po nejvyšší. Soubor smí importovat jen svou vrstvu a nižší.
  const layers = ['core', 'data', 'services', 'features'];

  /// Nejvyšší délka souboru v `lib/` (řádky).
  const maxLines = 600;

  /// Soubory, které limit překračují s vědomím (README, „Otevřené body“). Nový soubor
  /// sem nepatří: rozdělte ho. Když se některý z nich zkrátí pod limit, ze seznamu ho smažte.
  const knownOversized = {
    'services/prompt/system_prompt_builder.dart': 'výjimka z pravidla: texty promptů',
    'services/agents/voice_tutor_agent.dart': 'čeká na vyčlenění řízení tahů (bod 2 a 13)',
    'features/conversation/widgets/word_translation_sheet.dart': 'čeká na controller a menší widgety (bod 3)',
    'services/gemini/gemini_live_client.dart': 'čeká na samostatný parser zpráv (bod 3)',
  };

  final importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

  /// Cesta souboru od `lib/` s lomítky.
  String libPath(File file) => file.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^.*?lib/'), '');

  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// Vrstva souboru podle první složky; soubory přímo v `lib/` (main, app) jsou nad všemi.
  int layerOf(String path) {
    final index = layers.indexOf(path.split('/').first);
    return index == -1 ? layers.length : index;
  }

  /// Cíl importu [uri] ze souboru [from] jako cesta od `lib/`; null pro cizí balíčky a SDK.
  String? resolveImport(String from, String uri) {
    if (uri.startsWith('package:aj_tudor/')) return uri.substring('package:aj_tudor/'.length);
    if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;
    final segments = from.split('/')..removeLast();
    for (final part in uri.split('/')) {
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else if (part != '.') {
        segments.add(part);
      }
    }
    return segments.join('/');
  }

  test('the project sources were found', () {
    expect(sources.length, greaterThan(100), reason: 'test se musí pouštět z kořene projektu');
  });

  test('dependencies go one way: features → services → data → core', () {
    final violations = <String>[];
    for (final file in sources) {
      final from = libPath(file);
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final target = resolveImport(from, match.group(1)!);
        if (target != null && layerOf(target) > layerOf(from)) {
          violations.add('$from importuje $target');
        }
      }
    }
    expect(violations, isEmpty, reason: 'nižší vrstva nesmí importovat vyšší');
  });

  test('no file in lib/ is longer than $maxLines lines, except the known ones', () {
    final tooLong = <String>[];
    for (final file in sources) {
      final path = libPath(file);
      final lines = file.readAsLinesSync().length;
      if (lines > maxLines && !knownOversized.containsKey(path)) tooLong.add('$path ($lines řádků)');
    }
    expect(tooLong, isEmpty, reason: 'soubor rozdělte (části obrazovky do widgets/, logiku do controlleru nebo služby)');
  });

  test('the list of known oversized files is up to date', () {
    final paths = {for (final file in sources) libPath(file): file};
    final stale = <String>[];
    for (final path in knownOversized.keys) {
      final file = paths[path];
      if (file == null) {
        stale.add('$path už neexistuje');
      } else if (file.readAsLinesSync().length <= maxLines) {
        stale.add('$path už se pod limit vejde');
      }
    }
    expect(stale, isEmpty, reason: 'smažte je ze seznamu knownOversized');
  });

  test('only GeminiRestCore creates a Dio client', () {
    final creators = [
      for (final file in sources)
        if (RegExp(r'\bDio\(').hasMatch(file.readAsStringSync())) libPath(file),
    ];
    expect(creators, ['services/gemini/gemini_rest_core.dart']);
  });

  test('the API key is never put into a request URL, except the Live WebSocket', () {
    // Adresu požadavku Dart vypisuje do textu výjimek a ty končí v logu. REST posílá klíč
    // v hlavičce x-goog-api-key; adresa spojení s Gemini Live ho obsahovat musí.
    final withKeyInUrl = [
      for (final file in sources)
        if (RegExp(r'[?&]key=\$').hasMatch(file.readAsStringSync())) libPath(file),
    ];
    expect(withKeyInUrl, ['services/gemini/gemini_live_client.dart']);
  });
}
