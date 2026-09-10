import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import 'word_translation_sheet.dart';
import '../../services/gemini/translation_service.dart';

/// Model reprezentující jeden token v textu (slovo, interpunkci nebo mezeru).
class _TextToken {
  final String rawText;
  final String cleanWord;
  final bool isSelectableWord;
  final bool isBold;
  final bool isItalic;
  final int wordIndex;

  const _TextToken({
    required this.rawText,
    required this.cleanWord,
    required this.isSelectableWord,
    required this.isBold,
    required this.isItalic,
    required this.wordIndex,
  });
}

/// Interaktivní textový widget pro zprávy tutora.
///
/// Umožňuje:
/// 1. Klepnutí na libovolné slovo pro okamžitý překlad do češtiny.
/// 2. Přejetí prstem (drag) přes více slov pro výběr celé fráze.
/// 3. Klepnutí na první a následně na poslední slovo pro přesný výběr fráze.
/// 4. Automatické otevření [WordTranslationSheet] s uložením do Smart Flashcards.
class InteractiveTutorText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? strongStyle;
  final TextStyle? emStyle;
  final bool autoOpenTranslationSheet;
  final void Function(String selectedText, String fullSentence)? onSelection;

  const InteractiveTutorText({
    super.key,
    required this.text,
    this.style,
    this.strongStyle,
    this.emStyle,
    this.autoOpenTranslationSheet = true,
    this.onSelection,
  });

  @override
  ConsumerState<InteractiveTutorText> createState() => _InteractiveTutorTextState();
}

class _InteractiveTutorTextState extends ConsumerState<InteractiveTutorText> {
  late List<_TextToken> _tokens;
  final Map<int, GlobalKey> _wordKeys = {};

  int? _selectedStartIndex;
  int? _selectedEndIndex;

  Offset? _pointerDownPosition;
  bool _isVerticalScrollCandidate = false;
  bool _hasMovedSignificantly = false;

  @override
  void initState() {
    super.initState();
    _parseTokens();
  }

  @override
  void didUpdateWidget(covariant InteractiveTutorText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _parseTokens();
      _clearSelection();
    }
  }

  void _clearSelection() {
    if (mounted) {
      setState(() {
        _selectedStartIndex = null;
        _selectedEndIndex = null;
      });
    }
  }

  void _parseTokens() {
    _tokens = [];
    _wordKeys.clear();

    // Regulární výraz pro rozdělení textu na slova, interpunkci, mezery a nové řádky
    final regex = RegExp(r'(\n|\s+|[^\s\n]+)');
    final matches = regex.allMatches(widget.text);

    int wordIndexCounter = 0;

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      if (raw.isEmpty) continue;

      if (raw == '\n' || raw.trim().isEmpty) {
        // Bílé znaky / mezery / zalomení řádku
        _tokens.add(_TextToken(
          rawText: raw,
          cleanWord: '',
          isSelectableWord: false,
          isBold: false,
          isItalic: false,
          wordIndex: -1,
        ));
      } else {
        // Kontrola základního markdown formátování (**bold**, *italic*)
        bool isBold = false;
        bool isItalic = false;
        String displayText = raw;

        if (displayText.startsWith('**') && displayText.endsWith('**') && displayText.length > 4) {
          isBold = true;
          displayText = displayText.substring(2, displayText.length - 2);
        } else if (displayText.startsWith('*') && displayText.endsWith('*') && displayText.length > 2) {
          isItalic = true;
          displayText = displayText.substring(1, displayText.length - 1);
        }

        final clean = WordTranslationService.cleanWord(displayText);
        final isSelectable = clean.isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(clean);

        final currentIndex = isSelectable ? wordIndexCounter++ : -1;
        if (isSelectable) {
          _wordKeys[currentIndex] = GlobalKey();
        }

        _tokens.add(_TextToken(
          rawText: displayText,
          cleanWord: clean,
          isSelectableWord: isSelectable,
          isBold: isBold,
          isItalic: isItalic,
          wordIndex: currentIndex,
        ));
      }
    }
  }

  int? _findWordIndexAtPosition(Offset globalPosition) {
    for (final entry in _wordKeys.entries) {
      final key = entry.value;
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final localOffset = renderBox.globalToLocal(globalPosition);
        // Mírně rozšířený hit-test rámeček pro snazší trefení prstem
        final rect = Rect.fromLTWH(
          -4,
          -4,
          renderBox.size.width + 8,
          renderBox.size.height + 8,
        );
        if (rect.contains(localOffset)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  void _onWordTapped(int index) {
    HapticFeedback.selectionClick();

    if (_selectedStartIndex != null && _selectedStartIndex != index) {
      // Rozsahový výběr (klik na první, klik na druhé slovo)
      setState(() {
        _selectedEndIndex = index;
      });
      _finishSelection();
    } else {
      // Jedno slovo
      setState(() {
        _selectedStartIndex = index;
        _selectedEndIndex = index;
      });
      _finishSelection();
    }
  }

  void _finishSelection() {
    if (_selectedStartIndex == null || _selectedEndIndex == null) return;

    final start = math.min(_selectedStartIndex!, _selectedEndIndex!);
    final end = math.max(_selectedStartIndex!, _selectedEndIndex!);

    // Získáme vybraná slova
    final selectedCleanWords = <String>[];
    for (final token in _tokens) {
      if (token.isSelectableWord && token.wordIndex >= start && token.wordIndex <= end) {
        selectedCleanWords.add(token.cleanWord);
      }
    }

    if (selectedCleanWords.isEmpty) {
      _clearSelection();
      return;
    }

    final selectedPhrase = selectedCleanWords.join(' ');

    if (widget.onSelection != null) {
      widget.onSelection!(selectedPhrase, widget.text);
    }

    if (widget.autoOpenTranslationSheet) {
      WordTranslationSheet.show(
        context,
        englishText: selectedPhrase,
        contextSentence: widget.text,
        ref: ref,
        onDismissed: () {
          _clearSelection();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = AppTheme.textColor(context);

    final baseStyle = widget.style ??
        GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: defaultTextColor,
          height: 1.5,
        );

    final strongStyle = widget.strongStyle ??
        baseStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.primaryLight : AppTheme.primaryDark,
        );

    final emStyle = widget.emStyle ??
        baseStyle.copyWith(
          fontStyle: FontStyle.italic,
        );

    final activeRange = (_selectedStartIndex != null && _selectedEndIndex != null)
        ? (
            math.min(_selectedStartIndex!, _selectedEndIndex!),
            math.max(_selectedStartIndex!, _selectedEndIndex!),
          )
        : null;

    return Listener(
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
        _isVerticalScrollCandidate = false;
        _hasMovedSignificantly = false;
      },
      onPointerMove: (event) {
        if (_pointerDownPosition == null || _isVerticalScrollCandidate) return;

        final dx = (event.position.dx - _pointerDownPosition!.dx).abs();
        final dy = (event.position.dy - _pointerDownPosition!.dy).abs();

        // Pokud je pohyb primárně svislý (> 16 px a výrazně víc než dx), jde o scroll
        if (dy > 16 && dy > dx * 1.4) {
          _isVerticalScrollCandidate = true;
          return;
        }

        // Pokud se prst posunul vodorovně / po řádku o víc než 10 px, jedná se o tažení (drag select)
        if (dx > 10 || (dx > 6 && dy < 10)) {
          _hasMovedSignificantly = true;

          // Hledáme slovo pod aktuální pozicí
          final targetIndex = _findWordIndexAtPosition(event.position);
          if (targetIndex != null) {
            if (_selectedStartIndex == null) {
              final startIndex = _findWordIndexAtPosition(_pointerDownPosition!);
              setState(() {
                _selectedStartIndex = startIndex ?? targetIndex;
                _selectedEndIndex = targetIndex;
              });
              HapticFeedback.selectionClick();
            } else if (_selectedEndIndex != targetIndex) {
              setState(() {
                _selectedEndIndex = targetIndex;
              });
              HapticFeedback.selectionClick();
            }
          }
        }
      },
      onPointerUp: (event) {
        if (_hasMovedSignificantly && !_isVerticalScrollCandidate) {
          _finishSelection();
        }
        _pointerDownPosition = null;
        _hasMovedSignificantly = false;
        _isVerticalScrollCandidate = false;
      },
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 3,
        children: [
          for (final token in _tokens)
            if (token.rawText == '\n')
              const SizedBox(width: double.infinity, height: 4)
            else if (!token.isSelectableWord)
              Text(
                token.rawText,
                style: baseStyle,
              )
            else
              _buildSelectableWord(
                token: token,
                baseStyle: token.isBold
                    ? strongStyle
                    : (token.isItalic ? emStyle : baseStyle),
                isSelected: activeRange != null &&
                    token.wordIndex >= activeRange.$1 &&
                    token.wordIndex <= activeRange.$2,
                isDark: isDark,
              ),
        ],
      ),
    );
  }

  Widget _buildSelectableWord({
    required _TextToken token,
    required TextStyle baseStyle,
    required bool isSelected,
    required bool isDark,
  }) {
    final key = _wordKeys[token.wordIndex];

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onWordTapped(token.wordIndex),
          borderRadius: BorderRadius.circular(6),
          splashColor: AppTheme.primary.withValues(alpha: 0.25),
          highlightColor: AppTheme.primary.withValues(alpha: 0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? AppTheme.primary.withValues(alpha: 0.35)
                      : AppTheme.primary.withValues(alpha: 0.18))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppTheme.primaryLight : AppTheme.primary)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              token.rawText,
              style: isSelected
                  ? baseStyle.copyWith(
                      color: isDark ? Colors.white : AppTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    )
                  : baseStyle,
            ),
          ),
        ),
      ),
    );
  }
}

