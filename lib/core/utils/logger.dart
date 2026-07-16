import 'package:flutter/foundation.dart';

/// Centrální třída pro logování v aplikaci.
/// 
/// Umožňuje sjednotit formát výpisů do konzole a vizuálně odlišit různé typy zpráv
/// pomocí barevných emodži. V produkčním režimu jsou debug zprávy automaticky potlačeny.
class L {
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
}
