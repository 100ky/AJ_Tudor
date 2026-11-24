import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';

/// Položka spodní navigace: index stránky ve [SkeletonScreen], popisek a ikony.
class _Destination {
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _Destination(this.index, this.label, this.icon, this.selectedIcon);
}

/// Spodní navigace s Hovorem jako velkým tlačítkem uprostřed.
///
/// Pořadí na liště je Dril, Kartičky, Hovor, Pokrok, Profil. Indexy stránek zůstávají
/// 0 Hovor, 1 Dril, 2 Kartičky, 3 Pokrok, 4 Profil.
class AppNavigationBar extends StatelessWidget {
  /// Index vybrané stránky.
  final int currentIndex;

  /// Vybere stránku podle indexu.
  final ValueChanged<int> onSelect;

  /// Spustí hovor při druhém klepnutí na Hovor (když už je vybraná záložka Hovor).
  final VoidCallback? onStartCall;

  /// Počet kartiček připravených k dnešnímu opakování (odznak na Kartičkách).
  final int dueFlashcardsCount;

  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.onStartCall,
    this.dueFlashcardsCount = 0,
  });

  /// Výška lišty bez systémového okraje.
  static const double barHeight = 66;

  /// Kolik tlačítko Hovor přečnívá nad lištu.
  static const double overhang = 24;

  static const _left = [
    _Destination(1, 'Dril', Icons.edit_note_outlined, Icons.edit_note_rounded),
    _Destination(2, 'Kartičky', Icons.style_outlined, Icons.style_rounded),
  ];
  static const _right = [
    _Destination(3, 'Pokrok', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _Destination(4, 'Profil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _select(int index) {
    HapticFeedback.selectionClick();
    onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: overhang + barHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: overhang,
            bottom: 0,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.navBar,
                border: Border(top: BorderSide(color: AppTheme.hairline)),
              ),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 0,
            bottom: bottomInset,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in _left)
                  Expanded(
                    child: _NavItem(
                      d,
                      selected: d.index == currentIndex,
                      badgeCount: d.index == 2 ? dueFlashcardsCount : 0,
                      onTap: _select,
                    ),
                  ),
                Expanded(
                  child: _TalkButton(
                    selected: currentIndex == 0,
                    onTap: () => _select(0),
                    onStartCall: onStartCall,
                  ),
                ),
                for (final d in _right) Expanded(child: _NavItem(d, selected: d.index == currentIndex, onTap: _select)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final int badgeCount;
  final ValueChanged<int> onTap;

  const _NavItem(this.destination, {required this.selected, this.badgeCount = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.textPrimary : AppTheme.textSecondary;
    final badgeText = badgeCount > 99 ? '99+' : '$badgeCount';
    return Semantics(
      selected: selected,
      button: true,
      label: badgeCount > 0 ? '${destination.label}, $badgeCount k opakování' : destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onTap(destination.index),
        radius: 36,
        child: Padding(
          padding: const EdgeInsets.only(top: AppNavigationBar.overhang),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? destination.selectedIcon : destination.icon, size: 24, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      right: -10,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppTheme.navBar, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeText,
                          style: AppTheme.font(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.background,
                            height: 1.1,
                            fontFeatures: AppTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                maxLines: 1,
                style: AppTheme.font(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kulaté tlačítko Hovor přečnívající nad lištu: mimo Hovor bílé (přepne na Hovor),
/// na stránce Hovor zelené s popiskem „Začít“ (další klepnutí zahájí hovor).
class _TalkButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onStartCall;

  const _TalkButton({required this.selected, required this.onTap, this.onStartCall});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: selected ? 'Začít hovor' : 'Hovor',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected
            ? () {
                HapticFeedback.mediumImpact();
                onStartCall?.call();
              }
            : onTap,
        child: Column(
          children: [
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.success : AppTheme.textPrimary,
                boxShadow: const [
                  BoxShadow(color: AppTheme.navBar, spreadRadius: 6),
                  BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Icon(
                selected ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 28,
                color: selected ? Colors.white : AppTheme.background,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                selected ? 'Začít' : 'Hovor',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppTheme.font(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
