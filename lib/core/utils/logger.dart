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
class L {
  // ─────────────── ZÁKLADNÍ ÚROVNĚ ───────────────

  /// Loguje zprávu užitečnou pro ladění (pouze v debug režimu).
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('🔵 [DEBUG] $message');
    }
  }

  /// Loguje informativní zprávu o běžném chodu aplikace.
  static void i(String message) {
    debugPrint('🟢 [INFO] $message');
  }

  /// Loguje varování (např. neočekávaný stav, který nezpůsobil pád).
  static void w(String message) {
    debugPrint('🟠 [WARNING] $message');
  }

  /// Loguje chybu včetně volitelného objektu chyby a StackTrace.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('🔴 [ERROR] $message');
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
  }

  // ─────────────── KATEGORIZOVANÉ TAGY ───────────────

  /// Loguje zprávu s tagem [SESSION] — životní cyklus lekce.
  static void session(String message) {
    debugPrint('🟢 [SESSION] $message');
  }

  /// Loguje zprávu s tagem [PROMPT] — systémový prompt a jeho parametry.
  static void prompt(String message) {
    debugPrint('🟣 [PROMPT] $message');
  }

  /// Loguje zprávu s tagem [PROFILE] — data profilu studenta.
  static void profile(String message) {
    debugPrint('🧑 [PROFILE] $message');
  }

  /// Loguje zprávu s tagem [ANALYSIS] — výsledky analýzy lekce.
  static void analysis(String message) {
    debugPrint('🔬 [ANALYSIS] $message');
  }

  /// Loguje metriku s jednotným formátem: `📊 [METRIC] název: hodnota jednotka`.
  static void metric(String name, dynamic value, [String unit = '']) {
    final unitSuffix = unit.isNotEmpty ? ' $unit' : '';
    debugPrint('📊 [METRIC] $name: $value$unitSuffix');
  }

  /// Loguje zprávu s tagem [VAD] — detekce hlasové aktivity.
  static void vad(String message) {
    if (kDebugMode) {
      debugPrint('🎙️ [VAD] $message');
    }
  }

  /// Loguje zprávu s tagem [SCENARIO] — plánování scénářů.
  static void scenario(String message) {
    debugPrint('🎭 [SCENARIO] $message');
  }

  /// Loguje zprávu s tagem [TOPIC] — příprava konverzačních témat.
  static void topic(String message) {
    debugPrint('💬 [TOPIC] $message');
  }

  /// Loguje zprávu s tagem [DIRECTOR] — asynchronní režisér a pedagogický supervisor hovoru.
  static void director(String message) {
    debugPrint('🎬 [DIRECTOR] $message');
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
    debugPrint('$header$padding┐');
    for (final line in content.split('\n')) {
      if (line.trim().isNotEmpty) {
        debugPrint('│ $line');
      }
    }
    debugPrint('└${'─' * 59}┘');
  }

  /// Vykreslí ohraničený blok pro seznam položek (každá na novém řádku se strom-odrážkou).
  ///
  /// [items] je seznam řetězců, které budou zobrazeny s odrážkami ├─ / └─.
  static void blockList(String tag, String title, List<String> items) {
    if (items.isEmpty) return;
    final header = '┌─── [$tag] $title ';
    final padding = '─' * (60 - header.length).clamp(0, 60);
    debugPrint('$header$padding┐');
    for (int i = 0; i < items.length; i++) {
      final prefix = i < items.length - 1 ? '├─' : '└─';
      debugPrint('│  $prefix ${items[i]}');
    }
    debugPrint('└${'─' * 59}┘');
  }

  // ─────────────── SESSION SEPARÁTORY ───────────────

  /// Vizuální oddělovač začátku nové session/lekce.
  static void sessionStart(int sessionId, {String? scenario, String? level, bool immersive = false}) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║ 📚 SESSION START #$sessionId${' ' * (38 - sessionId.toString().length).clamp(0, 38)}║');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    debugPrint('🟢 [SESSION] Scénář: ${scenario ?? 'Volná konverzace'}');
    debugPrint('🟢 [SESSION] Úroveň: ${level ?? '?'} | Immersive: ${immersive ? 'ANO' : 'NE'}');
    debugPrint('');
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
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║ 📊 SESSION END #$sessionId — Délka: $durationStr${' ' * (25 - sessionId.toString().length - durationStr.length).clamp(0, 25)}║');
    debugPrint('╠══════════════════════════════════════════════════════╣');
    debugPrint('║ Zprávy: ${userMessages + tutorMessages} (user: $userMessages, tutor: $tutorMessages)${' ' * (30 - (userMessages + tutorMessages).toString().length - userMessages.toString().length - tutorMessages.toString().length).clamp(0, 30)}║');
    if (avgUserWords != null) {
      debugPrint('║ Průměrná délka odpovědi: ${avgUserWords.toStringAsFixed(1)} slov${' ' * (21 - avgUserWords.toStringAsFixed(1).length).clamp(0, 21)}║');
    }
    debugPrint('║ Reconnecty: $reconnects | Frustrace detekce: $frustrationDetections${' ' * (8 - reconnects.toString().length - frustrationDetections.toString().length).clamp(0, 8)}║');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  // ─────────────── STRUKTUROVANÝ MAP VÝPIS ───────────────

  /// Přehledný výpis `Map<String, dynamic>` jako ohraničený blok.
  ///
  /// Vhodné pro výpis výsledků Gemini Structured Outputs.
  static void structuredBlock(String tag, String title, Map<String, dynamic> data) {
    final header = '┌─── [$tag] $title ';
    final padding = '─' * (60 - header.length).clamp(0, 60);
    debugPrint('$header$padding┐');
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List) {
        if (value.isEmpty) {
          debugPrint('│ ${entry.key}: []');
        } else if (value.first is Map) {
          debugPrint('│ ${entry.key}: (${value.length} položek)');
          for (int i = 0; i < value.length; i++) {
            final prefix = i < value.length - 1 ? '├─' : '└─';
            final mapItem = value[i] as Map;
            final summary = mapItem.entries.map((e) => '${e.key}: ${truncate(e.value.toString(), 40)}').join(' | ');
            debugPrint('│   $prefix $summary');
          }
        } else {
          debugPrint('│ ${entry.key}: ${value.join(', ')}');
        }
      } else {
        debugPrint('│ ${entry.key}: ${truncate(value.toString(), 80)}');
      }
    }
    debugPrint('└${'─' * 59}┘');
  }

  /// Zkrátí text na zadanou maximální délku, přidá "..." pokud byl oříznut.
  static String truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}
