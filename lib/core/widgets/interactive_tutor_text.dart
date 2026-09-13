import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import 'word_translation_sheet.dart';
import '../../services/gemini/translation_service.dart';

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

/// Vlastní rozpoznávač gest pro výběr textu tahem.
///
/// Umožňuje označování přes více řádků:
/// 1. Pokud je pohyb primárně svislý a ještě nezačal výběr, odmítne se (`rejected`),
///    aby mohl rodičovský ListView hladce scrollovat.
/// 2. Jakmile uživatel pohne prstem po řádku (`dx > 8` nebo přejede na jiné slovo),
///    rozpoznávač gesto přijme (`accepted`), vyhraje arénu gest a zabrání scrollování chatu.
/// 3. Následný pohyb může volně pokračovat svisle na 2., 3. a další řádky bez přerušení.
class _TutorTextSelectionGestureRecognizer extends OneSequenceGestureRecognizer {
  _TutorTextSelectionGestureRecognizer();

  ValueChanged<Offset>? onDragStart;
  ValueChanged<Offset>? onDragUpdate;
  VoidCallback? onDragEnd;
  VoidCallback? onDragCancel;

  Offset? _startPosition;
  bool _hasResolved = false;
  bool _isSelecting = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _startPosition = event.position;
    _hasResolved = false;
    _isSelecting = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!_hasResolved && _startPosition != null) {
        final dx = (event.position.dx - _startPosition!.dx).abs();
        final dy = (event.position.dy - _startPosition!.dy).abs();

        // Pokud je pohyb primárně svislý bez vodorovného posunu, jedná se o scroll chatu -> odmítnout
        if (dy > 14 && dy > dx * 1.5) {
          _hasResolved = true;
          resolve(GestureDisposition.rejected);
          return;
        }

        // Pokud je pohyb do strany po řádku, jedná se o označování -> přijmout a uzamknout scroll
        if (dx > 8 || (dx > 4 && dy < 8)) {
          _hasResolved = true;
          _isSelecting = true;
          resolve(GestureDisposition.accepted);
          onDragStart?.call(_startPosition!);
          onDragUpdate?.call(event.position);
          return;
        }
      } else if (_isSelecting) {
        onDragUpdate?.call(event.position);
      }
    } else if (event is PointerUpEvent) {
      if (_isSelecting) {
        onDragEnd?.call();
      }
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      if (_isSelecting) {
        onDragCancel?.call();
      }
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'tutor_text_selection';

  @override
  void didStopTrackingLastPointer(int pointer) {
    _hasResolved = false;
    _isSelecting = false;
  }
}

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
    if (_wordKeys.isEmpty) return null;

    final geometries = <_WordGeometry>[];
    for (final entry in _wordKeys.entries) {
      final renderBox = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.attached) {
        final topLeft = renderBox.localToGlobal(Offset.zero);
        final rect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
        geometries.add(_WordGeometry(entry.key, rect));
      }
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
        _TutorTextSelectionGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_TutorTextSelectionGestureRecognizer>(
          () => _TutorTextSelectionGestureRecognizer(),
          (_TutorTextSelectionGestureRecognizer instance) {
            instance
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

