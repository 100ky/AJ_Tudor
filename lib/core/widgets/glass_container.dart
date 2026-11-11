import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Povrch karty: plná tmavá výplň se zaoblenými rohy, bez rozmazání a stínu.
///
/// Název zůstal z dřívějšího skleněného vzhledu, aby se nemusely měnit všechny obrazovky.
/// [blur] a [useSpecularBorder] už nic nedělají, zůstaly kvůli starším voláním.
class GlassContainer extends StatelessWidget {
  /// Obsah karty.
  final Widget child;

  /// Vnitřní odsazení. Výchozí: `EdgeInsets.all(16)`.
  final EdgeInsets padding;

  /// Zaoblení rohů. Výchozí: 16.
  final BorderRadius borderRadius;

  /// Bez účinku (dřívější rozmazání pozadí).
  final double blur;

  /// Barva výplně. Výchozí je [AppTheme.surface].
  final Color? color;

  /// Volitelný gradient výplně.
  final Gradient? gradient;

  /// Volitelný okraj. Výchozí je bez okraje.
  final BoxBorder? border;

  /// Bez účinku (dřívější světelný odlesk hrany).
  final bool useSpecularBorder;

  /// Bez účinku, zůstalo kvůli starším voláním.
  final double borderWidth;

  /// Volitelné stíny. Výchozí je bez stínu.
  final List<BoxShadow>? shadows;

  /// Volitelný margin kolem karty.
  final EdgeInsets? margin;

  /// Volitelná šířka karty.
  final double? width;

  /// Volitelná výška karty.
  final double? height;

  /// Ořezový režim pro vnitřní obsah.
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.blur = 0,
    this.color,
    this.gradient,
    this.border,
    this.useSpecularBorder = false,
    this.borderWidth = 1.0,
    this.shadows,
    this.margin,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppTheme.surface) : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border,
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
