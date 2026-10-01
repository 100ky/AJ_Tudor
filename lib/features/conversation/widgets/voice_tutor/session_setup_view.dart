import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Režim tématu před zahájením hovoru.
enum TopicMode {
  /// Téma připravené z historie.
  history,

  /// Role-play scénář.
  scenarios,

  /// Volný rozhovor.
  freeTalk,
}

/// Prázdný stav před hovorem: přepínač režimu tématu a obsah vybrané záložky.
class SessionSetupView extends StatelessWidget {
  final TopicMode activeMode;
  final ValueChanged<TopicMode> onModeChanged;

  /// Obsah aktivní záložky (s vlastním klíčem kvůli animaci přepnutí).
  final Widget tabContent;

  const SessionSetupView({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
    required this.tabContent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Přepínač režimu tématu ──────────────────────────────────────
            SegmentedButton<TopicMode>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              segments: const [
                ButtonSegment<TopicMode>(
                  value: TopicMode.history,
                  icon: Icon(Icons.lightbulb_rounded, size: 14),
                  label: Text('Historie', maxLines: 1),
                ),
                ButtonSegment<TopicMode>(
                  value: TopicMode.scenarios,
                  icon: Icon(Icons.theater_comedy_rounded, size: 14),
                  label: Text('Scénáře', maxLines: 1),
                ),
                ButtonSegment<TopicMode>(
                  value: TopicMode.freeTalk,
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: Text('Volný', maxLines: 1),
                ),
              ],
              selected: {activeMode},
              onSelectionChanged: (set) {
                HapticFeedback.selectionClick();
                onModeChanged(set.first);
              },
            ),

            const SizedBox(height: 14),

            // ── Obsah podle vybraného režimu ────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: tabContent,
            ),
          ],
        ),
      ),
    );
  }
}
