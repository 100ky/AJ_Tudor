import 'package:flutter/foundation.dart';

/// Jednoduchý logger pro sjednocení výpisů v aplikaci.
class L {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('🔵 [DEBUG] $message');
    }
  }

  static void i(String message) {
    debugPrint('🟢 [INFO] $message');
  }

  static void w(String message) {
    debugPrint('🟠 [WARNING] $message');
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('🔴 [ERROR] $message');
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
  }
}
