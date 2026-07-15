import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WakelockService {
  void enable() => WakelockPlus.enable();
  void disable() => WakelockPlus.disable();
}

final wakelockServiceProvider = Provider<WakelockService>((ref) => WakelockService());
