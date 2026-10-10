import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Rozpoznávač výběru fráze v textu tutora podržením a tažením.
///
/// Chová se jako výběr textu v Androidu: výběr začne až po podržení prstu na slově
/// ([kLongPressTimeout]). Jakýkoli pohyb před tím gesto odmítne, takže tah prstem
/// vždycky scrolluje rodičovským seznamem. Klepnutí na slovo (bez pohybu) obslouží
/// samo slovo, tento rozpoznávač ho pustí.
class TutorTextSelectionGestureRecognizer extends OneSequenceGestureRecognizer {
  TutorTextSelectionGestureRecognizer();

  /// Pohyb, po kterém už nejde o podržení, ale o scroll (menší než práh scrollu [kTouchSlop]).
  static const double _moveTolerance = 10;

  ValueChanged<Offset>? onDragStart;
  ValueChanged<Offset>? onDragUpdate;
  VoidCallback? onDragEnd;
  VoidCallback? onDragCancel;

  /// Zda dotyk na [Offset] (globální souřadnice) míří přímo na označitelné slovo.
  bool Function(Offset globalPos)? isOnWord;

  Offset? _startPosition;
  bool _isSelecting = false;
  Timer? _longPressTimer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (isOnWord?.call(event.position) != true) return;

    startTrackingPointer(event.pointer, event.transform);
    _startPosition = event.position;
    _isSelecting = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(kLongPressTimeout, () {
      final start = _startPosition;
      if (start == null) return;
      _isSelecting = true;
      resolve(GestureDisposition.accepted);
      HapticFeedback.mediumImpact();
      onDragStart?.call(start);
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (_isSelecting) {
        onDragUpdate?.call(event.position);
        return;
      }
      final start = _startPosition;
      if (start != null && (event.position - start).distance > _moveTolerance) {
        // Prst se pohnul dřív, než podržení zapnulo výběr: je to scroll
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
      }
    } else if (event is PointerUpEvent) {
      if (_isSelecting) {
        onDragEnd?.call();
      } else {
        // Krátké klepnutí patří slovu
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      if (_isSelecting) onDragCancel?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    // Arénu vyhrál scroll nebo klepnutí: podržení už výběr nezapne
    _longPressTimer?.cancel();
    stopTrackingPointer(pointer);
  }

  @override
  String get debugDescription => 'tutor_text_selection';

  @override
  void didStopTrackingLastPointer(int pointer) {
    _longPressTimer?.cancel();
    _startPosition = null;
    _isSelecting = false;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
