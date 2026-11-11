import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design systém aplikace AJ Tudor: jen tmavý vzhled („Noční studio“).
///
/// - Téměř černé neutrální pozadí, plné povrchy bez skla, rozmazání a stínů.
/// - Obsah ve skupinách s tenkými oddělovači místo samostatných karet.
/// - Barva jen tam, kde něco znamená: stav hlasové vlny a lepší/horší u čísel.
/// - Jedno písmo (Hanken Grotesk) v řezech 400–600.
///
/// Názvy jako [glass], [onBackground] nebo [outline] zůstaly ze světlého a skleněného
/// vzhledu, aby starší obrazovky dál fungovaly. Mají tmavé hodnoty.
abstract final class AppTheme {
  // ── Povrchy ───────────────────────────────────────────────────────────────

  /// Pozadí obrazovek.
  static const Color background = Color(0xFF0A0B0E);

  /// Skupina seznamu, karta.
  static const Color surface = Color(0xFF131519);

  /// Tlačítko nebo prvek položený na povrchu.
  static const Color surfaceRaised = Color(0xFF1C1F25);

  /// Vybraný segment přepínače, stopa grafu.
  static const Color surfaceHigh = Color(0xFF2A2E36);

  /// Spodní navigační lišta.
  static const Color navBar = Color(0xFF0E1013);

  /// Tenký oddělovač řádků (bílá na 8 %).
  static const Color hairline = Color(0x14FFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────

  /// Nadpisy a hlavní text.
  static const Color textPrimary = Color(0xFFF3F4F6);

  /// Popisy a vedlejší text.
  static const Color textSecondary = Color(0xFFA3A8B3);

  /// Popisky a poznámky, jen od 12 px.
  static const Color textTertiary = Color(0xFF80868F);

  // ── Akcenty a významové barvy ────────────────────────────────────────────

  /// Indigo: stav „přemýšlí“, odkazy a výběr ve starších obrazovkách.
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  /// Zelená: správně, zlepšení, stav „poslouchá“.
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);

  /// Oranžová: lekce s kartičkami, upozornění na akci.
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFB923C);

  /// Žlutá: pauza, připojování, „skoro správně“.
  static const Color warning = Color(0xFFF5C451);

  /// Červená: chyby a zhoršení.
  static const Color error = Color(0xFFF47C7C);

  /// Červená tlačítka Ukončit (s bílým textem).
  static const Color danger = Color(0xFFE5484D);

  /// Fialová: stav „mluví“.
  static const Color speaking = Color(0xFF8B5CF6);

  // ── Barvy typů chyb ───────────────────────────────────────────────────────

  static const Color grammar = Color(0xFFF59E0B);
  static const Color vocabulary = Color(0xFF60A5FA);
  static const Color pronunciation = Color(0xFFA78BFA);

  /// Vrátí barvu pro daný typ chyby.
  static Color errorTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'grammar':
        return grammar;
      case 'vocabulary':
        return vocabulary;
      case 'pronunciation':
        return pronunciation;
      default:
        return textSecondary;
    }
  }

  /// Vrátí ikonu pro daný typ chyby.
  static IconData errorTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'grammar':
        return Icons.architecture;
      case 'vocabulary':
        return Icons.abc;
      case 'pronunciation':
        return Icons.record_voice_over;
      default:
        return Icons.error_outline;
    }
  }

  // ── Starší názvy (tmavé hodnoty) ──────────────────────────────────────────

  static const Color backgroundDark = background;
  static const Color backgroundSecondary = surface;
  static const Color backgroundSecondaryDark = surface;
  static const Color glass = surface;
  static const Color glassDark = surface;
  static const Color glassLight = surfaceRaised;
  static const Color glassLightDark = surfaceRaised;
  static const Color glassBorder = hairline;
  static const Color glassBorderDark = hairline;
  static const List<BoxShadow> glassShadow = [];
  static const List<BoxShadow> glassShadowLight = [];
  static const List<BoxShadow> glassShadowDark = [];
  static const Color onBackground = textPrimary;
  static const Color onBackgroundDark = textPrimary;
  static const Color onSurface = Color(0xFFD3D6DC);
  static const Color onSurfaceDark = onSurface;
  static const Color onSurfaceMuted = textSecondary;
  static const Color onSurfaceMutedDark = textSecondary;
  static const Color onPrimary = Colors.white;
  static const Color outline = Color(0xFF262A31);
  static const Color outlineDark = outline;
  static const Color outlineLight = surfaceRaised;
  static const Color outlineLightDark = surfaceRaised;

  // ── Pomocné metody (aplikace je jen tmavá, kontext se nepoužívá) ──────────

  static bool isDark(BuildContext context) => true;
  static Color backgroundColor(BuildContext context) => background;
  static Color backgroundSecondaryColor(BuildContext context) => surface;
  static Color glassColor(BuildContext context) => surface;
  static Color glassLightColor(BuildContext context) => surfaceRaised;
  static Color glassBorderColor(BuildContext context) => hairline;
  static List<BoxShadow> glassShadows(BuildContext context) => const [];
  static List<BoxShadow> glassShadowsLight(BuildContext context) => const [];
  static Color textColor(BuildContext context) => textPrimary;
  static Color surfaceTextColor(BuildContext context) => onSurface;
  static Color mutedTextColor(BuildContext context) => textSecondary;
  static Color outlineColor(BuildContext context) => outline;
  static Color outlineLightColor(BuildContext context) => surfaceRaised;

  /// Písmo aplikace.
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    List<FontFeature>? fontFeatures,
  }) =>
      GoogleFonts.hankenGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: decoration,
        fontFeatures: fontFeatures,
      );

  /// Číslice stejné šířky pro čísla pod sebou a časy.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  // ── Barvy hlasové vlny podle stavu ────────────────────────────────────────

  static Color orbColorForState(String state) {
    switch (state) {
      case 'listening':
        return success;
      case 'speaking':
        return speaking;
      case 'thinking':
        return primary;
      case 'connecting':
      case 'reconnecting':
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'error':
        return danger;
      default: // idle
        return const Color(0xFFBFC0D6);
    }
  }

  /// Světlejší odstín stavu vlny pro text (popisek stavu, živý přepis).
  static Color stateTextColor(String state) {
    switch (state) {
      case 'listening':
        return successLight;
      case 'speaking':
        return const Color(0xFFB4A0FA);
      case 'thinking':
        return const Color(0xFFA5B4FC);
      case 'connecting':
      case 'reconnecting':
      case 'paused':
        return warning;
      case 'error':
        return error;
      default:
        return textSecondary;
    }
  }

  // ── ThemeData ─────────────────────────────────────────────────────────────

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: textPrimary,
    onPrimary: background,
    secondary: successLight,
    onSecondary: Colors.black,
    tertiary: accentLight,
    onTertiary: Colors.black,
    error: error,
    onError: Colors.black,
    surface: surface,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    surfaceContainerHighest: surfaceRaised,
    outline: outline,
    outlineVariant: hairline,
  );

  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.hankenGroteskTextTheme(ThemeData.dark().textTheme);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: -1.0),
      displayMedium: base.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: base.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: base.bodyLarge?.copyWith(color: onSurface, fontSize: 16, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: onSurface, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: textSecondary),
      labelLarge: base.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: background,
        canvasColor: background,
        textTheme: _buildTextTheme(),
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: font(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
          iconTheme: const IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: textPrimary,
            foregroundColor: background,
            textStyle: font(fontSize: 15, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: outline),
            textStyle: font(fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: textPrimary,
            textStyle: font(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: textSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          hintStyle: font(color: textTertiary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: textSecondary, width: 1),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceHigh,
          contentTextStyle: font(color: textPrimary, fontSize: 14),
          actionTextColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceRaised,
          labelStyle: font(fontSize: 12.5, fontWeight: FontWeight.w500, color: onSurface),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        dividerTheme: const DividerThemeData(color: hairline, thickness: 1, space: 1),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: surface,
            foregroundColor: textSecondary,
            selectedForegroundColor: textPrimary,
            selectedBackgroundColor: surfaceHigh,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            iconSize: 15,
            textStyle: font(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: font(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
          contentTextStyle: font(fontSize: 14.5, color: onSurface, height: 1.45),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: textPrimary),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return background;
            return textSecondary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return success;
            return surfaceHigh;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      );
}
