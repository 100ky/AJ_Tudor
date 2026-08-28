import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centrální design systém aplikace AJ Tudor – Light & Dark Glassmorphism.
///
/// Vizuální jazyk založený na:
/// - Světlém / Hlubokém nočním pozadí s ambientními gradient bloby
/// - Frosted glass kartách (průsvitná výplň + blur + jemný odlesk na hranách)
/// - Měkkých stínech místo ostrých okrajů
/// - Vibrantních akcentech (indigo, emerald, violet, orange)
abstract final class AppTheme {
  // ── Pozadí (Light) ────────────────────────────────────────────────────────

  /// Hlavní pozadí – jemný šedofialový (ne čistě bílý, aby glass vyniknul)
  static const Color background = Color(0xFFF4F2FA);

  /// Sekundární pozadí pro mírný kontrast
  static const Color backgroundSecondary = Color(0xFFEBE8F4);

  // ── Pozadí (Dark) ─────────────────────────────────────────────────────────

  /// Hluboké tmavě fialové pozadí pro tmavý režim
  static const Color backgroundDark = Color(0xFF0D0B18);

  /// Sekundární tmavé pozadí
  static const Color backgroundSecondaryDark = Color(0xFF171328);

  // ── Glass povrchy (Light) ─────────────────────────────────────────────────

  /// Standardní glass karta (~80% bílá)
  static const Color glass = Color(0xCCFFFFFF);

  /// Lehčí glass (~60% bílá) pro vnořené prvky
  static const Color glassLight = Color(0x99FFFFFF);

  /// Jemný border glass karet (subtilní bílý okraj simulující odlesk světla)
  static const Color glassBorder = Color(0x55FFFFFF);

  /// Stín pro glass karty – měkký a rozptýlený
  static const List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Lehčí stín pro menší prvky
  static const List<BoxShadow> glassShadowLight = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  // ── Glass povrchy (Dark) ──────────────────────────────────────────────────

  /// Standardní tmavá glass karta (~80% tmavě fialová)
  static const Color glassDark = Color(0xCC1A162B);

  /// Lehčí tmavý glass pro vnořené prvky
  static const Color glassLightDark = Color(0x99241F3A);

  /// Jemný odlesk pro tmavé karty
  static const Color glassBorderDark = Color(0x22FFFFFF);

  /// Stín pro tmavé glass karty
  static const List<BoxShadow> glassShadowDark = [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  // ── Primární barvy ────────────────────────────────────────────────────────

  /// Primární indigo – navigace, hlavní akce, tutorovy zprávy
  static const Color primary = Color(0xFF6366F1);

  /// Světlejší varianta
  static const Color primaryLight = Color(0xFF818CF8);

  /// Tmavší varianta
  static const Color primaryDark = Color(0xFF4F46E5);

  // ── Sémantické barvy ──────────────────────────────────────────────────────

  /// Zelená – správné odpovědi, listening stav, progress
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);

  /// Oranžová – akcent, CTA, streak, energie
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFB923C);

  /// Amber – pauza, connecting, varování
  static const Color warning = Color(0xFFF59E0B);

  /// Červená – chyby
  static const Color error = Color(0xFFEF4444);

  /// Violet – speaking stav tutora
  static const Color speaking = Color(0xFF8B5CF6);

  // ── Barvy typů chyb (Progress, History) ───────────────────────────────────

  /// Gramatické chyby – amber
  static const Color grammar = Color(0xFFF59E0B);

  /// Slovníkové chyby – blue
  static const Color vocabulary = Color(0xFF3B82F6);

  /// Výslovnostní chyby – violet
  static const Color pronunciation = Color(0xFF8B5CF6);

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
        return onSurfaceMuted;
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

  // ── Dekorativní gradient bloby ────────────────────────────────────────────

  /// Indigo blob (pozadí – levý horní roh)
  static const Color blobPrimary = Color(0x306366F1);

  /// Pink blob (pozadí – pravý spodní roh)
  static const Color blobSecondary = Color(0x30EC4899);

  /// Cyan blob (pozadí – centrální)
  static const Color blobTertiary = Color(0x3006B6D4);

  // ── Text (Light) ──────────────────────────────────────────────────────────

  /// Hlavní text na pozadí – hluboká indigo
  static const Color onBackground = Color(0xFF1E1B4B);

  /// Sekundární text na kartách
  static const Color onSurface = Color(0xFF374151);

  /// Ztlumený text (labely, placeholdery)
  static const Color onSurfaceMuted = Color(0xFF9CA3AF);

  /// Text na primárním povrchu
  static const Color onPrimary = Colors.white;

  // ── Text (Dark) ───────────────────────────────────────────────────────────

  /// Hlavní text v tmavém režimu
  static const Color onBackgroundDark = Color(0xFFF8FAFC);

  /// Sekundární text v tmavém režimu
  static const Color onSurfaceDark = Color(0xFFE2E8F0);

  /// Ztlumený text v tmavém režimu
  static const Color onSurfaceMutedDark = Color(0xFF94A3B8);

  // ── Okraje ────────────────────────────────────────────────────────────────

  /// Standardní border (Light)
  static const Color outline = Color(0xFFE5E7EB);

  /// Velmi jemný border (Light)
  static const Color outlineLight = Color(0xFFF3F4F6);

  /// Standardní border (Dark)
  static const Color outlineDark = Color(0xFF2E2A44);

  /// Velmi jemný border (Dark)
  static const Color outlineLightDark = Color(0xFF221E36);

  // ── Adaptivní pomocné metody pro barvy dle tématu ────────────────────────

  /// Adaptivní barva hlavního textu (nadpisy, tituly, výrazné texty)
  static Color textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? onBackgroundDark
          : onBackground;

  /// Adaptivní barva běžného textu na kartách
  static Color surfaceTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? onSurfaceDark
          : onSurface;

  /// Adaptivní ztlumený text (popisky, labely, placeholdery)
  static Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? onSurfaceMutedDark
          : onSurfaceMuted;

  /// Adaptivní barva okrajů
  static Color outlineColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? outlineDark
          : outline;

  /// Adaptivní barva jemných okrajů/oddělovačů
  static Color outlineLightColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? outlineLightDark
          : outlineLight;

  // ── Speciální barvy hlasového orbu podle stavu ────────────────────────────

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
        return warning;
      case 'paused':
        return warning;
      case 'error':
        return error;
      default: // idle
        return const Color(0xFFBFC0D6);
    }
  }

  // ── ColorScheme ───────────────────────────────────────────────────────────

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: success,
    onSecondary: onPrimary,
    tertiary: accent,
    onTertiary: onPrimary,
    error: error,
    onError: onPrimary,
    surface: glass,
    onSurface: onSurface,
    surfaceContainerHighest: backgroundSecondary,
    outline: outline,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLight,
    onPrimary: Colors.white,
    secondary: successLight,
    onSecondary: Colors.black,
    tertiary: accentLight,
    onTertiary: Colors.black,
    error: error,
    onError: Colors.white,
    surface: glassDark,
    onSurface: onSurfaceDark,
    surfaceContainerHighest: backgroundSecondaryDark,
    outline: outlineDark,
  );

  // ── Typografie ────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme({required bool isDark}) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    final textColor = isDark ? onBackgroundDark : onBackground;
    final surfaceTextColor = isDark ? onSurfaceDark : onSurface;
    final mutedTextColor = isDark ? onSurfaceMutedDark : onSurfaceMuted;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: surfaceTextColor,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: surfaceTextColor,
        height: 1.4,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: mutedTextColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Finální Světlé ThemeData ──────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: background,
    textTheme: _buildTextTheme(isDark: false),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      iconTheme: const IconThemeData(color: onBackground),
    ),

    // NavigationBar (dolní lišta) – glass efekt
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: glass,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: 0.12),
      elevation: 0,
      height: 76,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? primary : onSurfaceMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected ? primary : onSurfaceMuted,
          size: 22,
        );
      }),
    ),

    // Card – glass styl
    cardTheme: CardThemeData(
      color: glass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.08),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    // InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glass,
      hintStyle: TextStyle(color: onSurfaceMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onBackground,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: glass,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      side: BorderSide(color: outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: outlineLight,
      thickness: 1,
      space: 1,
    ),

    // SegmentedButton
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: glass,
        foregroundColor: onSurfaceMuted,
        selectedForegroundColor: primary,
        selectedBackgroundColor: primary.withValues(alpha: 0.10),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconSize: 15,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return onSurfaceMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.3);
        }
        return outline;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );

  // ── Finální Tmavé ThemeData ───────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: backgroundDark,
    textTheme: _buildTextTheme(isDark: true),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onBackgroundDark,
      ),
      iconTheme: const IconThemeData(color: onBackgroundDark),
    ),

    // NavigationBar (dolní lišta) – tmavý glass efekt
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: glassDark,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primaryLight.withValues(alpha: 0.18),
      elevation: 0,
      height: 76,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? primaryLight : onSurfaceMutedDark,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected ? primaryLight : onSurfaceMutedDark,
          size: 22,
        );
      }),
    ),

    // Card – tmavý glass styl
    cardTheme: CardThemeData(
      color: glassDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.3),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: BorderSide(color: primaryLight.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    // InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassDark,
      hintStyle: TextStyle(color: onSurfaceMutedDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryLight, width: 1.5),
      ),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: glassDark,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: glassDark,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurfaceDark,
      ),
      side: BorderSide(color: outlineDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: outlineLightDark,
      thickness: 1,
      space: 1,
    ),

    // SegmentedButton
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: glassDark,
        foregroundColor: onSurfaceMutedDark,
        selectedForegroundColor: primaryLight,
        selectedBackgroundColor: primaryLight.withValues(alpha: 0.15),
        side: BorderSide(color: outlineDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconSize: 15,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundSecondaryDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryLight;
        return onSurfaceMutedDark;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryLight.withValues(alpha: 0.35);
        }
        return outlineDark;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
