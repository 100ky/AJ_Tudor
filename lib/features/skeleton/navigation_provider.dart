import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier pro správu indexu vybrané záložky v dolní navigaci.
class MainNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Globální provider pro index vybrané stránky v hlavní navigaci.
final mainNavigationIndexProvider =
    NotifierProvider<MainNavigationNotifier, int>(MainNavigationNotifier.new);
