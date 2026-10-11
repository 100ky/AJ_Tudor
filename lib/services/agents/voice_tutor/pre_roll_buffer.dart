import 'dart:collection';

/// Posledních pár set milisekund zvuku z mikrofonu před zjištěnou řečí.
///
/// Místní detekce řeči pozná začátek až po prvních blocích zvuku. Při ruční detekci
/// řeči server úvod před `activityStart` sám nedoplní, takže by bez této paměti
/// dostal větu bez první slabiky.
class PreRollBuffer {
  /// Kolik bajtů zvuku se drží (16 000 B = 0,5 s PCM 16-bit, 16 kHz, mono).
  final int maxBytes;

  final Queue<List<int>> _chunks = Queue();
  int _bytes = 0;

  PreRollBuffer({this.maxBytes = 16000});

  /// Přidá blok zvuku; nejstarší bloky nad limit zahodí (poslední blok zůstane vždy).
  void add(List<int> chunk) {
    _chunks.addLast(chunk);
    _bytes += chunk.length;
    while (_bytes > maxBytes && _chunks.length > 1) {
      _bytes -= _chunks.removeFirst().length;
    }
  }

  /// Vrátí uložené bloky od nejstaršího a paměť vyprázdní.
  List<List<int>> drain() {
    final chunks = _chunks.toList();
    clear();
    return chunks;
  }

  void clear() {
    _chunks.clear();
    _bytes = 0;
  }
}
