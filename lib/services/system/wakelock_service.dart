import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drží displej rozsvícený, dokud ho potřebuje aspoň jeden držitel: hovor, nebo rozbor
/// lekce. Zhasnutý displej odpojí aplikaci od sítě (9. 11.: rozbor lekce dvakrát selhal).
class WakelockService {
  final Set<Object> _holders = {};

  /// Rozsvítí displej pro [holder] (výchozí je hovor).
  void enable([Object holder = 'hovor']) {
    _holders.add(holder);
    WakelockPlus.enable();
  }

  /// Uvolní displej držitele [holder]. Zhasnout smí, až ho nedrží nikdo.
  void disable([Object holder = 'hovor']) {
    _holders.remove(holder);
    if (_holders.isEmpty) WakelockPlus.disable();
  }
}

final wakelockServiceProvider = Provider<WakelockService>((ref) => WakelockService());
