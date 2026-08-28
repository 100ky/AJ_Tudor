import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Znovupoužitelný glassmorphism kontejner s adaptivní podporou světlého a tmavého režimu.
///
/// Vytváří efekt matného skla s:
/// - BackdropFilter (blur pozadí za kartou)
/// - Poloprůhlednou výplní (světlou / tmavou dle tématu)
/// - Jemným odleskem na hranách
/// - Měkkým stínem pro dojem vznášení
class GlassContainer extends StatelessWidget {
  /// Obsah uvnitř glass kontejneru.
  final Widget child;

  /// Vnitřní odsazení. Výchozí: `EdgeInsets.all(16)`.
  final EdgeInsets padding;

  /// Zaoblení rohů. Výchozí: 20.
  final BorderRadius borderRadius;

  /// Intenzita rozmazání pozadí. Výchozí: 12.0.
  final double blur;

  /// Barva výplně glass kontejneru. Pokud není specifikována, adaptuje se dle tématu.
  final Color? color;

  /// Volitelný vlastní border.
  final BoxBorder? border;

  /// Volitelné vlastní stíny.
  final List<BoxShadow>? shadows;

  /// Volitelný margin kolem kontejneru.
  final EdgeInsets? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 12.0,
    this.color,
    this.border,
    this.shadows,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ?? (isDark ? AppTheme.glassDark : AppTheme.glass);
    final effectiveShadows =
        shadows ?? (isDark ? AppTheme.glassShadowDark : AppTheme.glassShadow);
    final effectiveBorder = border ??
        Border.all(
          color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorder,
          width: 1.0,
        );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: borderRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
