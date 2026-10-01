import '../../data/database/app_database.dart';

/// Jedna studijní relace kartiček se stabilním pořadím.
///
/// Fronta se sestaví z kartiček k opakování na začátku relace a dál se mění jen
/// hodnocením („Znovu“ vrací kartičku na konec) nebo smazáním, takže počítadlo
/// „Kartička X z Y“ neskáče, když kartičky po ohodnocení zmizí z databázového dotazu.
class ReviewSession {
  final List<Flashcard> _queue;
  int _index = 0;
  int _masteredCount = 0;
  int _againCount = 0;
  bool _completed;

  ReviewSession(List<Flashcard> dueCards)
      : _queue = List<Flashcard>.from(dueCards),
        _completed = dueCards.isEmpty;

  /// Relace bez jediné kartičky.
  bool get isEmpty => _queue.isEmpty;

  /// Všechny kartičky relace jsou ohodnocené.
  bool get isFinished => _completed || _index >= _queue.length;

  /// Kartička, která je právě na řadě.
  Flashcard get current => _queue[_index];

  /// Pořadí aktuální kartičky (od 0).
  int get index => _index;

  /// Počet kartiček v relaci včetně těch vrácených „Znovu“.
  int get total => _queue.length;

  /// Kartičky ohodnocené jako „Dobré“ nebo „Snadné“.
  int get masteredCount => _masteredCount;

  /// Kartičky vrácené na konec fronty hodnocením „Znovu“.
  int get againCount => _againCount;

  /// Zaznamená hodnocení aktuální kartičky (0 = Znovu … 3 = Snadné) a posune se dál.
  void recordAnswer(Flashcard card, int rating) {
    if (rating >= 2) {
      _masteredCount++;
    } else if (rating == 0) {
      _againCount++;
      _queue.add(card);
    }
    _index++;
    if (_index >= _queue.length) _completed = true;
  }

  /// Odebere smazanou kartičku z relace.
  void remove(int cardId) {
    _queue.removeWhere((c) => c.id == cardId);
    if (_index >= _queue.length) _completed = true;
  }
}
