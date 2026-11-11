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

/// Spodní navigace s Hovorem jako velkým bílým tlačítkem uprostřed.
///
/// Pořadí na liště je Dril, Kartičky, Hovor, Pokrok, Profil. Indexy stránek zůstávají
/// 0 Hovor, 1 Dril, 2 Kartičky, 3 Pokrok, 4 Profil.
class AppNavigationBar extends StatelessWidget {
  /// Index vybrané stránky.
  final int currentIndex;

  /// Vybere stránku podle indexu.
  final ValueChanged<int> onSelect;

  const AppNavigationBar({super.key, required this.currentIndex, required this.onSelect});

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
                for (final d in _left) Expanded(child: _NavItem(d, selected: d.index == currentIndex, onTap: _select)),
                Expanded(child: _TalkButton(selected: currentIndex == 0, onTap: () => _select(0))),
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
  final ValueChanged<int> onTap;

  const _NavItem(this.destination, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.textPrimary : AppTheme.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onTap(destination.index),
        radius: 36,
        child: Padding(
          padding: const EdgeInsets.only(top: AppNavigationBar.overhang),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? destination.selectedIcon : destination.icon, size: 24, color: color),
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

/// Bílé kulaté tlačítko Hovor, přečnívá nad lištu.
class _TalkButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _TalkButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'Hovor',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: 2),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.textPrimary,
                boxShadow: [
                  BoxShadow(color: AppTheme.navBar, spreadRadius: 6),
                  BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Icon(
                selected ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 28,
                color: AppTheme.background,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                'Hovor',
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
