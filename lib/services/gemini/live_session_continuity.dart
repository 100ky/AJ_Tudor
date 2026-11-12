import '../../core/utils/logger.dart';

/// Zkušební „souvislý hovor“ pro Gemini Live.
///
/// Zapnutý hovor požádá server o token pro navázání na stejný hovor (`sessionResumption`)
/// a o průběžné zkracování kontextu (`contextWindowCompression`). Když pak spojení spadne,
/// nové se přihlásí tokenem a server v hovoru pokračuje tam, kde skončil. Vypnutý hovor
/// po výpadku dostane jen textové shrnutí od režiséra.
///
/// Když server pole odmítne (zavře spojení s kódem dřív, než potvrdí nastavení), ubírá se
/// postupně: nejdřív token, pak komprese, nakonec i žádost o token. Lekce pak běží jako
/// bez souvislého hovoru. S dřívějším modelem (3.1-flash-live-preview) končilo navázání
/// tokenem smyčkou zavření 1007.
class LiveSessionContinuity {
  /// Zda hovor souvislý hovor zkouší. Nastavuje se před začátkem lekce.
  bool enabled = false;

  /// Od kolika tokenů server kontext zkracuje a na kolik. Systémový prompt (asi 6 400
  /// tokenů) zůstává vždy. Agent bez komprese obnovuje spojení při 25 tisících tokenech,
  /// komprese má zasáhnout dřív.
  static const int compressionTriggerTokens = 20000;
  static const int compressionTargetTokens = 13000;

  // Co všechno spojení posílá: 2 = žádost o token i kompresi kontextu, 1 = jen žádost
  // o token, 0 = nic (server to v této lekci odmítl).
  int _level = 2;

  // Poslední token od serveru, se kterým jde na hovor navázat
  String? _handle;

  // Co neslo nastavení aktuálního spojení
  bool _setupHadFields = false;
  bool _setupHadHandle = false;

  /// Aktuální spojení se přihlásilo tokenem předchozího, takže server v hovoru pokračuje
  /// a kontext není potřeba posílat znovu.
  bool get resumed => _setupHadHandle;

  /// Token, který nese nastavení aktuálního spojení (do logu nepatří).
  String? get handleInSetup => _setupHadHandle ? _handle : null;

  /// Nová lekce: nenavazuje na žádný předchozí hovor a zkouší souvislý hovor celý.
  void startLesson() {
    _handle = null;
    _level = 2;
  }

  /// Otevírá se nové spojení a jeho nastavení ještě neodešlo.
  void startConnection() {
    _setupHadFields = false;
    _setupHadHandle = false;
  }

  /// Pole, která se přidají do zprávy `setup` (přímo do ní, ne do `generationConfig`).
  /// Bez tokenu znamená `sessionResumption` jen žádost, aby server tokeny posílal.
  Map<String, dynamic> setupFields() {
    final active = enabled && _level > 0;
    final handle = active ? _handle : null;
    _setupHadFields = active;
    _setupHadHandle = handle != null;
    if (!active) return const {};

    L.i('Souvislý hovor: ${handle != null ? 'navazuji tokenem na předchozí spojení' : 'žádám server o token'}'
        '${_level == 2 ? ', kontext se zkracuje od $compressionTriggerTokens tokenů' : ''}.');
    return {
      'sessionResumption': {'handle': ?handle},
      if (_level == 2)
        'contextWindowCompression': {
          'slidingWindow': {'targetTokens': compressionTargetTokens},
          'triggerTokens': compressionTriggerTokens,
        },
    };
  }

  /// Zpráva `sessionResumptionUpdate` ze serveru. Token platí jen z chvíle, kdy na hovor
  /// navázat jde; když server hlásí, že to teď nejde (model zrovna mluví), zůstává předchozí.
  void onServerUpdate(Map<dynamic, dynamic> update) {
    final newHandle = update['newHandle'] ?? update['new_handle'];
    final resumable = update['resumable'] == true;
    final hasHandle = newHandle is String && newHandle.isNotEmpty;
    if (enabled && resumable && hasHandle) _handle = newHandle;
    L.d('SessionResumptionUpdate: resumable=$resumable, token '
        '${hasHandle ? 'přišel (${newHandle.length} znaků)' : 'nepřišel'}'
        '${enabled ? '' : ', souvislý hovor je vypnutý'}.');
  }

  /// Zapomene token: další spojení začne s prázdným kontextem. Hodí se, když stav hovoru
  /// na serveru za navázání nestojí (model neodpovídá, kontext je moc velký, konec lekce).
  void forget() {
    if (_handle != null) L.i('Souvislý hovor: token zahozen, další spojení začne znovu.');
    _handle = null;
  }

  /// Server spojení odmítl dřív, než potvrdil nastavení. Pokud nastavení neslo pole
  /// souvislého hovoru, ubere se z nich. Vrátí, zda se něco ubralo (další pokus má smysl).
  bool degrade(String reason) {
    if (!_setupHadFields) return false;
    if (_setupHadHandle) {
      _handle = null;
      L.w('Souvislý hovor: server odmítl spojení s tokenem ($reason). Zkusím to bez něj, hovor dostane shrnutí.');
    } else if (_level == 2) {
      _level = 1;
      L.w('Souvislý hovor: server odmítl nastavení ($reason). Zkusím to bez komprese kontextu.');
    } else {
      _level = 0;
      L.w('Souvislý hovor: server odmítl i samotnou žádost o token ($reason). Tato lekce poběží bez něj.');
    }
    // Další pokus nesmí stejné odmítnutí započítat znovu
    startConnection();
    return true;
  }
}
