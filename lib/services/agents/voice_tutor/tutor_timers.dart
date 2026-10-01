import 'dart:async';

/// Hlídací časovače hlasového hovoru.
enum TutorTimer {
  /// 45 s bez jakékoli aktivity → reconnect (tichý rozpad socketu).
  watchdog,

  /// Tutor „mluví“, ale nechodí audio ani konec tahu → zpět do poslechu.
  stuck,

  /// Tutor příliš dlouho „přemýšlí“ → zpět do poslechu.
  thinking,

  /// Model po domluvení studenta neodpovídá → popostrčení, pak reconnect.
  responseSilence,

  /// Ticho po řeči studenta → konec jeho promluvy.
  vadSilence,

  /// Dohrání audia tutora → přechod do poslechu.
  playbackComplete,
}

/// Drží běžící časovače hovoru; každý druh časovače běží nejvýš jednou.
class TutorTimers {
  final Map<TutorTimer, Timer> _timers = {};

  /// (Pře)spustí časovač [timer]; předchozí stejného druhu zruší.
  void start(TutorTimer timer, Duration duration, void Function() onFire) {
    _timers[timer]?.cancel();
    _timers[timer] = Timer(duration, onFire);
  }

  /// Zruší časovač [timer], pokud běží.
  void cancel(TutorTimer timer) => _timers.remove(timer)?.cancel();

  /// Zda časovač [timer] právě běží.
  bool isActive(TutorTimer timer) => _timers[timer]?.isActive ?? false;

  /// Zruší všechny časovače (konec, pauza nebo zánik hovoru).
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
