import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import 'tutor_text_selection_recognizer.dart';
import 'tutor_text_tokens.dart';
import 'word_translation_sheet.dart';

/// Pomocná třída reprezentující geometrii jednoho slova pro 2D hit-testing.
class _WordGeometry {
  final int index;
  final Rect rect;
  const _WordGeometry(this.index, this.rect);
}

/// Pomocná třída reprezentující jeden vizuální řádek slov.
class _TextLineGeometry {
  final List<_WordGeometry> words;
  _TextLineGeometry(this.words);

  double get top => words.map((w) => w.rect.top).reduce(math.min);
  double get bottom => words.map((w) => w.rect.bottom).reduce(math.max);
  double get centerDy => (top + bottom) / 2;

  void add(_WordGeometry g) => words.add(g);
}

/// Interaktivní textový widget pro zprávy tutora.
///
/// Umožňuje:
/// 1. Klepnutí na anglické slovo pro okamžitý překlad do češtiny.
/// 2. Podržení slova a tažení přes další slova pro výběr celé fráze. Tah bez podržení scrolluje.
/// 3. Klepnutí na první a následně na poslední slovo pro přesný výběr fráze.
/// 4. Otevření [WordTranslationSheet], kde jde překlad uložit do kartiček.
///
/// Slova českých vět jsou obyčejný text (viz [tokenizeTutorText]).
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
  late List<TutorTextToken> _tokens;
  final Map<int, GlobalKey> _wordKeys = {};

  int? _selectedStartIndex;
  int? _selectedEndIndex;

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
    _tokens = tokenizeTutorText(widget.text);
    _wordKeys
      ..clear()
      ..addEntries(_tokens
          .where((t) => t.isSelectableWord)
          .map((t) => MapEntry(t.wordIndex, GlobalKey())));
  }

  /// Obdélník slova [index] v globálních souřadnicích (null, pokud ještě není vykreslené).
  Rect? _wordRect(int index) {
    final renderBox = _wordKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return null;
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  /// Zda dotyk míří přímo na některé označitelné slovo.
  bool _isOnWord(Offset globalPosition) {
    return _wordKeys.keys
        .any((index) => _wordRect(index)?.inflate(4).contains(globalPosition) ?? false);
  }

  int? _findWordIndexAtPosition(Offset globalPosition) {
    if (_wordKeys.isEmpty) return null;

    final geometries = <_WordGeometry>[];
    for (final index in _wordKeys.keys) {
      final rect = _wordRect(index);
      if (rect != null) geometries.add(_WordGeometry(index, rect));
    }

    if (geometries.isEmpty) return null;

    // 1. Přímý hit-test v mírně rozšířeném obdélníku každého slova
    for (final g in geometries) {
      if (g.rect.inflate(4).contains(globalPosition)) {
        return g.index;
      }
    }

    // 2. Seskupení slov do vizuálních řádků podle svislého středu
    geometries.sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    final lines = <_TextLineGeometry>[];
    for (final g in geometries) {
      if (lines.isEmpty) {
        lines.add(_TextLineGeometry([g]));
      } else {
        final lastLine = lines.last;
        if ((g.rect.center.dy - lastLine.centerDy).abs() < 10) {
          lastLine.add(g);
        } else {
          lines.add(_TextLineGeometry([g]));
        }
      }
    }

    // Seřadíme slova uvnitř každého řádku zleva doprava
    for (final line in lines) {
      line.words.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    // 3. Najdeme nejvhodnější řádek podle Y souřadnice
    _TextLineGeometry bestLine = lines.first;
    if (globalPosition.dy <= lines.first.bottom) {
      bestLine = lines.first;
    } else if (globalPosition.dy >= lines.last.top) {
      bestLine = lines.last;
    } else {
      double minDyDist = double.infinity;
      for (final line in lines) {
        double dist = 0;
        if (globalPosition.dy < line.top) {
          dist = line.top - globalPosition.dy;
        } else if (globalPosition.dy > line.bottom) {
          dist = globalPosition.dy - line.bottom;
        } else {
          dist = 0;
        }
        if (dist < minDyDist) {
          minDyDist = dist;
          bestLine = line;
        }
      }
    }

    // 4. Na zvoleném řádku najdeme slovo podle X souřadnice
    final words = bestLine.words;
    if (words.isEmpty) return null;

    if (globalPosition.dx <= words.first.rect.right) {
      return words.first.index;
    }
    if (globalPosition.dx >= words.last.rect.left) {
      return words.last.index;
    }

    _WordGeometry bestWord = words.first;
    double minDxDist = double.infinity;
    for (final w in words) {
      double dist = 0;
      if (globalPosition.dx < w.rect.left) {
        dist = w.rect.left - globalPosition.dx;
      } else if (globalPosition.dx > w.rect.right) {
        dist = globalPosition.dx - w.rect.right;
      } else {
        dist = 0;
      }
      if (dist < minDxDist) {
        minDxDist = dist;
        bestWord = w;
      }
    }

    return bestWord.index;
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

    return RawGestureDetector(
      gestures: {
        TutorTextSelectionGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TutorTextSelectionGestureRecognizer>(
          () => TutorTextSelectionGestureRecognizer(),
          (TutorTextSelectionGestureRecognizer instance) {
            instance
              ..isOnWord = _isOnWord
              ..onDragStart = (pos) {
                final targetIndex = _findWordIndexAtPosition(pos);
                if (targetIndex != null) {
                  setState(() {
                    _selectedStartIndex = targetIndex;
                    _selectedEndIndex = targetIndex;
                  });
                  HapticFeedback.selectionClick();
                }
              }
              ..onDragUpdate = (pos) {
                final targetIndex = _findWordIndexAtPosition(pos);
                if (targetIndex != null) {
                  if (_selectedStartIndex == null) {
                    setState(() {
                      _selectedStartIndex = targetIndex;
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
              ..onDragEnd = () {
                _finishSelection();
              }
              ..onDragCancel = () {
                _clearSelection();
              };
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
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
                style: token.isBold
                    ? strongStyle
                    : (token.isItalic ? emStyle : baseStyle),
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
    required TutorTextToken token,
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

