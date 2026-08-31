import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Znovupoužitelný glassmorphism kontejner s adaptivní podporou světlého a tmavého režimu (Glassmorphism 2.0).
///
/// Poskytuje:
/// - BackdropFilter (přirozený frosted glass blur)
/// - Specular Gradient Rim Border (světelný odlesk na horní hraně)
/// - Jemný gradient výplně simulující lom světla
/// - Hluboké ambientní a kontaktní stíny
class GlassContainer extends StatelessWidget {
  /// Obsah uvnitř glass kontejneru.
  final Widget child;

  /// Vnitřní odsazení. Výchozí: `EdgeInsets.all(16)`.
  final EdgeInsets padding;

  /// Zaoblení rohů. Výchozí: 20.
  final BorderRadius borderRadius;

  /// Intenzita rozmazání pozadí. Výchozí: 16.0.
  final double blur;

  /// Barva výplně glass kontejneru. Pokud není specifikována, adaptuje se dle tématu.
  final Color? color;

  /// Volitelný gradient výplně.
  final Gradient? gradient;

  /// Volitelný vlastní border. Pokud není zadán a [useSpecularBorder] je true, použije se gradientní odlesk.
  final BoxBorder? border;

  /// Zda použít moderní gradientní odlesk hrany (specular rim lighting). Výchozí: true.
  final bool useSpecularBorder;

  /// Tloušťka gradientního okraje. Výchozí: 1.0.
  final double borderWidth;

  /// Volitelné vlastní stíny.
  final List<BoxShadow>? shadows;

  /// Volitelný margin kolem kontejneru.
  final EdgeInsets? margin;

  /// Volitelná šířka kontejneru.
  final double? width;

  /// Volitelná výška kontejneru.
  final double? height;

  /// Ořezový režim pro vnitřní obsah.
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 16.0,
    this.color,
    this.gradient,
    this.border,
    this.useSpecularBorder = true,
    this.borderWidth = 1.0,
    this.shadows,
    this.margin,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveShadows = shadows ?? AppTheme.glassShadows(context);
    final effectiveGradient = gradient ??
        (color == null ? AppTheme.glassFillGradient(context) : null);
    final effectiveColor =
        effectiveGradient == null ? (color ?? AppTheme.glassColor(context)) : null;

    final hasCustomBorder = border != null;
    final useRimGradient = useSpecularBorder && !hasCustomBorder && borderWidth > 0;

    Widget glassBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        gradient: effectiveGradient,
        borderRadius: borderRadius,
        border: hasCustomBorder
            ? border
            : (useRimGradient
                ? null
                : Border.all(
                    color: AppTheme.glassBorderColor(context),
                    width: borderWidth,
                  )),
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );

    // Pokud je aktivní specular rim gradient, obalíme tělo do jemného gradientního rámečku
    if (useRimGradient) {
      glassBody = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: AppTheme.glassBorderGradient(context),
        ),
        padding: EdgeInsets.all(borderWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            (borderRadius.topLeft.x - borderWidth).clamp(0.0, 999.0),
          ),
          child: glassBody,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: glassBody,
        ),
      ),
    );
  }
}
