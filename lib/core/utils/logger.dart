import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centrální třída pro logování v aplikaci.
/// 
/// Umožňuje sjednotit formát výpisů do konzole a vizuálně odlišit různé typy zpráv
/// pomocí barevných emodži. V produkčním režimu jsou debug zprávy automaticky potlačeny.
///
/// Podporuje:
/// - **Kategorizované tagy** (`[SESSION]`, `[PROMPT]`, `[PROFILE]`, `[ANALYSIS]`, `[METRIC]`, `[VAD]`, `[SCENARIO]`, `[TOPIC]`)
///   pro snadné filtrování v Android Studio Logcat.
/// - **Blokový výpis** s vizuálními rámečky pro přehledné sekce.
/// - **Session separátory** pro oddělení lekcí v logu.
/// - **Metrický řádek** pro jednotný formát metrik.
/// - **JSON pretty print** pro strukturovaná data.
/// - **Zápis do souboru** při ladění ([startFileLog]).
class L {
  static IOSink? _fileSink;

  /// Začne zapisovat log i do `logs/latest.log` v [directory]; předchozí běh zůstane v `previous.log`.
  ///
  /// Slouží k ladění na telefonu: výpis z konzole bývá na sdílení moc dlouhý,
  /// soubor jde stáhnout přes `adb exec-out run-as <balíček> cat app_flutter/logs/latest.log`.
  static Future<void> startFileLog(Directory directory) async {
    try {
      final logDir = Directory('${directory.path}/logs');
      await logDir.create(recursive: true);
      final latest = File('${logDir.path}/latest.log');
      if (await latest.exists()) {
        await latest.rename('${logDir.path}/previous.log');
      }
      _fileSink = latest.openWrite();
    } catch (e) {
      debugPrint('Nepodařilo se otevřít soubor logu: $e');
    }
  }

  /// Vypíše řádek do konzole a případně i do souboru logu s časem.
  static void _out(String line) {
    debugPrint(line);
    final sink = _fileSink;
    if (sink == null) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    sink.writeln('${two(now.hour)}:${two(now.minute)}:${two(now.second)}.$ms $line');
  }

  // ─────────────── ZÁKLADNÍ ÚROVNĚ ───────────────

  /// Loguje zprávu užitečnou pro ladění (pouze v debug režimu).
  static void d(String message) {
    if (kDebugMode) {
      _out('🔵 [DEBUG] $message');
    }
  }

  /// Loguje informativní zprávu o běžném chodu aplikace.
  static void i(String message) {
    _out('🟢 [INFO] $message');
  }

  /// Loguje varování (např. neočekávaný stav, který nezpůsobil pád).
  static void w(String message) {
    _out('🟠 [WARNING] $message');
  }

  /// Loguje chybu včetně volitelného objektu chyby a StackTrace.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _out('🔴 [ERROR] $message');
    if (error != null) _out('   Error: $error');
    if (stackTrace != null) _out('   StackTrace: $stackTrace');
  }

  // ─────────────── KATEGORIZOVANÉ TAGY ───────────────

  /// Loguje zprávu s tagem [SESSION] — životní cyklus lekce.
  static void session(String message) {
    _out('🟢 [SESSION] $message');
  }

  /// Loguje zprávu s tagem [PROMPT] — systémový prompt a jeho parametry.
  static void prompt(String message) {
    _out('🟣 [PROMPT] $message');
  }

  /// Loguje zprávu s tagem [PROFILE] — data profilu studenta.
  static void profile(String message) {
    _out('🧑 [PROFILE] $message');
  }

  /// Loguje zprávu s tagem [ANALYSIS] — výsledky analýzy lekce.
  static void analysis(String message) {
    _out('🔬 [ANALYSIS] $message');
  }

  /// Loguje metriku s jednotným formátem: `📊 [METRIC] název: hodnota jednotka`.
  static void metric(String name, dynamic value, [String unit = '']) {
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';
    _out('📊 [METRIC] $name: $value$unitSuffix');
  }

  /// Loguje zprávu s tagem [VAD] — detekce hlasové aktivity.
  static void vad(String message) {
    if (kDebugMode) {
      _out('🎙️ [VAD] $message');
    }
  }

  /// Loguje zprávu s tagem [SCENARIO] — plánování scénářů.
  static void scenario(String message) {
    _out('🎭 [SCENARIO] $message');
  }

  /// Loguje zprávu s tagem [TOPIC] — příprava konverzačních témat.
  static void topic(String message) {
    _out('💬 [TOPIC] $message');
  }

  /// Loguje zprávu s tagem [DIRECTOR] — asynchronní režisér a pedagogický supervisor hovoru.
  static void director(String message) {
    _out('🎬 [DIRECTOR] $message');
  }


  // ─────────────── BLOKOVÝ VÝPIS ───────────────

  /// Vykreslí ohraničený blok s nadpisem a obsahem pro snadné vizuální hledání v Logcat.
  ///
  /// Příklad:
  /// ```
  /// ┌─── [PROFILE] Profil studenta ────────────────┐
  /// │ Úroveň: B1
  /// │ Fakta: Má psa, rád jezdí na kole
  /// └──────────────────────────────────────────────┘
  /// ```
  static void block(String tag, String title, String content) {
    final header = '┌─── [$tag] $title ';
    final padding = '─' * (60 - header.length).clamp(0, 60);
    _out('$header$padding┐');
    for (final line in content.split('\n')) {
      if (line.trim().isNotEmpty) {
        _out('│ $line');
      }
    }
    _out('└${'─' * 59}┘');
  }

  /// Vykreslí ohraničený blok pro seznam položek (každá na novém řádku se strom-odrážkou).
  ///
  /// [items] je seznam řetězců, které budou zobrazeny s odrážkami ├─ / └─.
  static void blockList(String tag, String title, List<String> items) {
    if (items.isEmpty) return;
    final header = '┌─── [$tag] $title ';
    final padding = '─' * (60 - header.length).clamp(0, 60);
    _out('$header$padding┐');
    for (int i = 0; i < items.length; i++) {
      final prefix = i < items.length - 1 ? '├─' : '└─';
      _out('│  $prefix ${items[i]}');
    }
    _out('└${'─' * 59}┘');
  }

  // ─────────────── SESSION SEPARÁTORY ───────────────

  /// Vizuální oddělovač začátku nové session/lekce.
  static void sessionStart(int sessionId, {String? scenario, String? level, bool immersive = false}) {
    _out('');
    _out('╔══════════════════════════════════════════════════════╗');
    _out('║ 📚 SESSION START #$sessionId${' ' * (38 - sessionId.toString().length).clamp(0, 38)}║');
    _out('╚══════════════════════════════════════════════════════╝');
    _out('🟢 [SESSION] Scénář: ${scenario ?? 'Volná konverzace'}');
    _out('🟢 [SESSION] Úroveň: ${level ?? '?'} | Immersive: ${immersive ? 'ANO' : 'NE'}');
    _out('');
  }

  /// Vizuální oddělovač konce session se souhrnem metrik.
  static void sessionEnd({
    required int sessionId,
    required Duration duration,
    required int userMessages,
    required int tutorMessages,
    double? avgUserWords,
    int reconnects = 0,
    int frustrationDetections = 0,
  }) {
    final durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    _out('');
    _out('╔══════════════════════════════════════════════════════╗');
    _out('║ 📊 SESSION END #$sessionId — Délka: $durationStr${' ' * (25 - sessionId.toString().length - durationStr.length).clamp(0, 25)}║');
    _out('╠══════════════════════════════════════════════════════╣');
    _out('║ Zprávy: ${userMessages + tutorMessages} (user: $userMessages, tutor: $tutorMessages)${' ' * (30 - (userMessages + tutorMessages).toString().length - userMessages.toString().length - tutorMessages.toString().length).clamp(0, 30)}║');
    if (avgUserWords != null) {
      _out('║ Průměrná délka odpovědi: ${avgUserWords.toStringAsFixed(1)} slov${' ' * (21 - avgUserWords.toStringAsFixed(1).length).clamp(0, 21)}║');
    }
    _out('║ Reconnecty: $reconnects | Frustrace detekce: $frustrationDetections${' ' * (8 - reconnects.toString().length - frustrationDetections.toString().length).clamp(0, 8)}║');
    _out('╚══════════════════════════════════════════════════════╝');
    _out('');
  }

  // ─────────────── STRUKTUROVANÝ MAP VÝPIS ───────────────

  /// Přehledný výpis `Map<String, dynamic>` jako ohraničený blok.
  ///
  /// Vhodné pro výpis výsledků Gemini Structured Outputs.
  static void structuredBlock(String tag, String title, Map<String, dynamic> data) {
    final header = '┌─── [$tag] $title ';
    final padding = '─' * (60 - header.length).clamp(0, 60);
    _out('$header$padding┐');
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List) {
        if (value.isEmpty) {
          _out('│ ${entry.key}: []');
        } else if (value.first is Map) {
          _out('│ ${entry.key}: (${value.length} položek)');
          for (int i = 0; i < value.length; i++) {
            final prefix = i < value.length - 1 ? '├─' : '└─';
            final mapItem = value[i] as Map;
            final summary = mapItem.entries.map((e) => '${e.key}: ${truncate(e.value.toString(), 40)}').join(' | ');
            _out('│   $prefix $summary');
          }
        } else {
          _out('│ ${entry.key}: ${value.join(', ')}');
        }
      } else {
        _out('│ ${entry.key}: ${truncate(value.toString(), 80)}');
      }
    }
    _out('└${'─' * 59}┘');
  }

  /// Zkrátí text na zadanou maximální délku, přidá "..." pokud byl oříznut.
  static String truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}
