import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centrální design systém aplikace AJ Tudor.
///
/// Definuje barevnou paletu, typografii a tvary konzistentně
/// dle psychologie barev pro vzdělávací aplikace:
/// - Modrá: soustředění a produktivita (primary)
/// - Zelená: úspěch a pozitivní zpětná vazba (success/listening)
/// - Oranžová: energie a pozornost (accent/CTA)
abstract final class AppTheme {
  // ── Barevné tokeny ──────────────────────────────────────────────────────────

  /// Primární modrá – tutorovy zprávy, navigace, soustředění
  static const Color primary = Color(0xFF1A73E8);

  /// Světlejší varianty primární modré
  static const Color primaryLight = Color(0xFF4A9EFF);
  static const Color primaryDark = Color(0xFF0D47A1);

  /// Zelená – listening stav, správné odpovědi, progress
  static const Color success = Color(0xFF34A853);
  static const Color successLight = Color(0xFF4CAF72);

  /// Oranžová – akcent, CTA, streak, energie
  static const Color accent = Color(0xFFFF6D00);
  static const Color accentLight = Color(0xFFFF8F00);

  /// Amber – pauza, connecting, varování
  static const Color warning = Color(0xFFF9A825);

  /// Červená – chyby (měkká, ne agresivní)
  static const Color error = Color(0xFFE53935);

  /// Fialová – speaking stav tutora
  static const Color speaking = Color(0xFF7C4DFF);

  // ── Povrchy (tmavý režim) ─────────────────────────────────────────────────

  /// Nejhlubší pozadí
  static const Color background = Color(0xFF0A0A14);

  /// Povrch karet, dialogů
  static const Color surface = Color(0xFF12121E);

  /// Elevovaný povrch (listy, bubliny)
  static const Color surfaceVariant = Color(0xFF1A1A2E);

  /// Jemný oddělovač / border
  static const Color outline = Color(0xFF2A2A40);

  // ── Text ──────────────────────────────────────────────────────────────────

  static const Color onPrimary = Colors.white;
  static const Color onBackground = Color(0xFFE8E8F0);
  static const Color onSurface = Color(0xFFD0D0E0);
  static const Color onSurfaceMuted = Color(0xFF7070A0);

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
        return const Color(0xFF3A3A5C);
    }
  }

  // ── ColorScheme ───────────────────────────────────────────────────────────

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    secondary: success,
    onSecondary: onPrimary,
    tertiary: accent,
    onTertiary: onPrimary,
    error: error,
    onError: onPrimary,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    outline: outline,
  );

  // ── Typografie ────────────────────────────────────────────────────────────

  static TextTheme get _textTheme {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: onSurface,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: onSurface,
        height: 1.4,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: onSurfaceMuted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Finální ThemeData ─────────────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: background,
    textTheme: _textTheme,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: background,
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

    // NavigationBar (dolní lišta)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primary.withValues(alpha: 0.15),
      height: 76, // Vyšší = labely jako 'Nastavení' se nevlévají pryč
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 10,
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

    // Card
    cardTheme: CardThemeData(
      color: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: outline, width: 1),
      ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
    ),

    // InputDecoration (TextField)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      hintStyle: TextStyle(color: onSurfaceMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceVariant,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      side: const BorderSide(color: outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: outline,
      thickness: 1,
      space: 1,
    ),

    // SegmentedButton
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: surfaceVariant,
        foregroundColor: onSurfaceMuted,
        selectedForegroundColor: primary,
        selectedBackgroundColor: primary.withValues(alpha: 0.12),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconSize: 15, // Menší ikona = více místa pro text
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12, // 13 → 12: zabrání zlomu řádky
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
