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
  ///
  /// Server práh počítá jinak než `usageMetadata.totalTokenCount`, podle kterého se řídí
  /// agent: v lekci 29 s prahem 20 000 zkrátil kontext až při 24 404 tokenech (na 14 192),
  /// tedy těsně pod hranicí 25 tisíc, při které by agent spojení obnovil a kompresi tím
  /// zmařil. S prahem 16 000 má zkracování přijít kolem 20 tisíc tokenů.
  static const int compressionTriggerTokens = 16000;
  static const int compressionTargetTokens = 13000;

  // Co všechno spojení posílá: 2 = žádost o token i kompresi kontextu, 1 = jen žádost
  // o token, 0 = nic (server to v této lekci odmítl).
  int _level = 2;

  // Poslední token od serveru, se kterým jde na hovor navázat
  String? _handle;

  // Co neslo nastavení aktuálního spojení
  bool _setupHadFields = false;
  bool _setupHadHandle = false;

  /// Kolikrát za sebou se zkusí navázat tokenem, když server hlásí, že předchozí spojení
  /// ještě drží. Mezi pokusy jsou 2 s, celkem tedy asi 10 s navíc, než hovor dostane shrnutí.
  static const int maxBusyRetries = 4;

  /// Za jak dlouho se navázání tokenem zkusí znovu.
  static const Duration busyRetryDelay = Duration(seconds: 2);

  // Kolikrát už server navázání odmítl, protože předchozí spojení ještě drží, a odkdy
  int _busyRetries = 0;
  DateTime? _busySince;

  /// Aktuální spojení se přihlásilo tokenem předchozího, takže server v hovoru pokračuje
  /// a kontext není potřeba posílat znovu.
  bool get resumed => _setupHadHandle;

  /// Token, který nese nastavení aktuálního spojení (do logu nepatří).
  String? get handleInSetup => _setupHadHandle ? _handle : null;

  /// Nová lekce: nenavazuje na žádný předchozí hovor a zkouší souvislý hovor celý.
  void startLesson() {
    _handle = null;
    _level = 2;
    _busyRetries = 0;
    _busySince = null;
  }

  /// Server potvrdil nastavení aktuálního spojení.
  void onSetupComplete() {
    final since = _busySince;
    if (since != null && _setupHadHandle) {
      L.i('Souvislý hovor: server předchozí spojení uvolnil po '
          '${DateTime.now().difference(since).inSeconds} s ($_busyRetries. opakování).');
    }
    _busyRetries = 0;
    _busySince = null;
  }

  /// Server navázání tokenem odmítl, protože předchozí spojení ještě považuje za živé.
  /// Stává se to po výpadku sítě: klient o konci spojení ví hned, server až po chvíli
  /// (lekce 28: deset vteřin po vypnutí Wi-Fi ho ještě držel). Token je v pořádku, takže
  /// se navázání zkusí znovu. Vrátí false, když už se čekalo dost a má přijít shrnutí.
  bool retryWhileStillConnected(String reason) {
    if (!_setupHadHandle || !reason.contains('already connected')) return false;
    if (_busyRetries >= maxBusyRetries) return false;
    _busyRetries++;
    _busySince ??= DateTime.now();
    L.w('Souvislý hovor: server ještě drží předchozí spojení, navázání zkusím znovu '
        'za ${busyRetryDelay.inSeconds} s ($_busyRetries/$maxBusyRetries).');
    startConnection();
    return true;
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
        '${_level == 2 ? ', kontext se zkracuje (práh $compressionTriggerTokens tokenů)' : ''}.');
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
    _busyRetries = 0;
    _busySince = null;
  }

  /// Server spojení odmítl dřív, než potvrdil nastavení. Pokud nastavení neslo pole
  /// souvislého hovoru, ubere se z nich. Vrátí, zda se něco ubralo (další pokus má smysl).
  bool degrade(String reason) {
    if (!_setupHadFields) return false;
    if (_setupHadHandle) {
      _handle = null;
      _busyRetries = 0;
      _busySince = null;
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
