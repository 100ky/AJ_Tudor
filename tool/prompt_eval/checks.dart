/// Automatické kontroly odpovědi tutora podle pravidel jeho systémového promptu.
///
/// Kontrolují jen to, co jde spočítat z textu (otázky, výzva k zopakování, délka).
/// Jestli tutor opravil správnou chybu, posuzuje rozhodčí model v `run.dart`.
library;

import 'package:aj_tudor/services/flashcards/conversation_cards.dart';

/// Druh situace, podle které se odpověď kontroluje.
enum CaseKind {
  /// Skutečná chyba: opravit, bez otázky k tématu, skončit výzvou k zopakování.
  correct,

  /// Správně, nebo jen drobnost: neopravovat, zareagovat, nejvýš jedna otázka.
  noCorrection,

  /// Česká věta nebo „jak se řekne“: dát anglickou verzi, bez „neříkáme“.
  translate,

  /// Student přemýšlí: jen krátce počkat.
  wait,

  /// Student zopakoval opravenou větu: pochválit a vrátit se k tématu jednou otázkou.
  continueTopic,

  /// Krátká odpověď: povzbudit jednou otázkou.
  encourage,

  /// Nesrozumitelný přepis: doptat se.
  clarify,

  /// Dotaz nebo žádost studenta: odpovědět.
  answer,

  /// Student zopakoval první opravu: vrátit se k druhé chybě z téže promluvy.
  secondError,

  /// Téma dobíhá: zůstat u něj jednou otázkou, neuhnout k jídlu a koníčkům.
  stayOnTopic;

  /// Druh podle názvu v souboru s případy.
  static CaseKind parse(String name) => switch (name) {
        'correct' => correct,
        'no_correction' => noCorrection,
        'translate' => translate,
        'wait' => wait,
        'continue' => continueTopic,
        'encourage' => encourage,
        'clarify' => clarify,
        'answer' => answer,
        'second_error' => secondError,
        'stay_on_topic' => stayOnTopic,
        _ => throw ArgumentError('Neznámý druh případu: $name'),
      };
}

/// Výsledek jedné kontroly.
class ReplyCheck {
  const ReplyCheck(this.name, {required this.passed});

  final String name;
  final bool passed;

  Map<String, Object> toJson() => {'name': name, 'passed': passed};
}

/// Kolik slov smí mít odpověď mimo opravu (pravidlo „max 30 slov“ v promptu).
const int maxPlainReplyWords = 30;

/// Kolik slov smí mít krátké čekání („Take your time…“).
const int maxWaitWords = 8;

final RegExp _repeatRequest = RegExp(
  r'zkus|zopakuj|zopakov|try saying|try to say|try it|say it|can you say|could you say|repeat',
  caseSensitive: false,
);

// Citovaná anglická věta k zopakování může končit otazníkem, otázkou k tématu ale není
final RegExp _quoted = RegExp(r'"[^"]*"|„[^“”"]*[“”"]|“[^”]*”');

final RegExp _leak = RegExp(r'\[DIRECTOR|SYSTEM INSTRUCTION|\*\*|^#', multiLine: true);

/// Věty odpovědi (dělené za . ! ? …).
List<String> sentencesOf(String reply) => reply
    .replaceAll(_quoted, '"…"')
    .split(RegExp(r'(?<=[.!?…])\s+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Zda věta vybízí studenta, ať něco zopakuje nebo zkusí říct.
bool isRepeatRequest(String sentence) => _repeatRequest.hasMatch(sentence);

/// Zda je odpověď opravou nebo pomocí s výrazem (obsahuje výzvu k zopakování).
bool isCorrectionTurn(String reply) => sentencesOf(reply).any(isRepeatRequest);

/// Otázky k tématu: věty s otazníkem mimo citace, které nejsou výzvou k zopakování.
int topicQuestions(String reply) =>
    sentencesOf(reply).where((s) => s.endsWith('?') && !isRepeatRequest(s)).length;

/// Počet slov odpovědi.
int wordCount(String reply) =>
    reply.split(RegExp(r'\s+')).where((w) => RegExp(r'\w').hasMatch(w)).length;

/// Zda odpověď končí výzvou k zopakování (výzva je v poslední nebo předposlední větě).
bool endsWithRepeatRequest(String reply) {
  final sentences = sentencesOf(reply);
  final tail = sentences.length <= 2 ? sentences : sentences.sublist(sentences.length - 2);
  return tail.any(isRepeatRequest);
}

// „Klasika“, ke které tutor uhýbá: jídlo, vaření, zahrada, koníčky, odpočinek
final List<RegExp> _classicTopics = [
  for (final pattern in [
    r'\bfood', r'\bcook', r'\bmeals?\b', r'\bdish(es)?\b', r'\bdinner', r'\blunch', r'\bbreakfast',
    r'\brecipe', r'\beat(s|ing)?\b', r'\bpasta', r'\bpizza', r'\bspaghetti', r'\bherbs?\b', r'\bbasil',
    r'\bthyme', r'\bgarden', r'\bgrill', r'\bbarbecue', r'\bbbq\b', r'\bsteak', r'\bpies?\b', r'\beggnog',
    r'\bdessert', r'\bcakes?\b', r'\bsoup', r'\bhobb(y|ies)', r'\bfree time', r'\bspare time', r'\brelax',
    r'\bunwind', r'\bdetective', r'\bmyster(y|ies)', r'\bbirthday', r'jídl', r'vaře', r'vaří', r'bylink',
    r'zahrad', r'recept', r'koníč', r'volný čas', r'volném čase', r'odpoč', r'detektiv', r'narozenin',
  ])
    RegExp(pattern, caseSensitive: false),
];

/// Témata z „klasiky“ (jídlo, koníčky…), která odpověď zmíní, i když o nich
/// v [recentContext] (posledních replikách) řeč nebyla.
List<String> classicTopicDrift(String reply, String recentContext) => [
      for (final topic in _classicTopics)
        if (topic.hasMatch(reply) && !topic.hasMatch(recentContext)) topic.firstMatch(reply)![0]!.toLowerCase(),
    ];

const Set<String> _stopWords = {
  'what', 'which', 'when', 'where', 'who', 'why', 'how', 'the', 'and', 'for', 'you', 'your', 'are', 'was',
  'were', 'did', 'does', 'have', 'has', 'had', 'with', 'about', 'that', 'this', 'there', 'any', 'some',
  'like', 'would', 'could', 'can', 'will', 'from', 'into', 'just', 'really', 'also', 'all', 'our', 'its',
  'they', 'them', 'their', 'then', 'than', 'more', 'most', 'much', 'very', 'been', 'being', 'usually',
  'now', 'ever', 'else', 'one', 'those', 'these', 'don', 'doing', 'get', 'got', 'jak', 'jaký', 'jaké',
  'kde', 'kdy', 'nebo', 'ale', 'tak', 'už', 'ještě', 'taky', 'máš', 'děláš',
};

Set<String> _contentWords(String sentence) => RegExp(r'\p{L}+', unicode: true)
    .allMatches(sentence.toLowerCase())
    .map((m) => m[0]!)
    .where((w) => w.length > 2 && !_stopWords.contains(w))
    .toSet();

/// Zda odpověď znovu klade otázku, kterou tutor v lekci už položil
/// (aspoň 75 % významových slov kratší z obou otázek je společných).
bool repeatsEarlierQuestion(String reply, Iterable<String> earlierTutorLines) {
  final earlier = [
    for (final line in earlierTutorLines)
      for (final sentence in sentencesOf(line))
        if (sentence.endsWith('?')) _contentWords(sentence),
  ].where((words) => words.length >= 3).toList();
  for (final question in sentencesOf(reply).where((s) => s.endsWith('?') && !isRepeatRequest(s))) {
    final words = _contentWords(question);
    if (words.length < 3) continue;
    for (final other in earlier) {
      final shorter = words.length < other.length ? words.length : other.length;
      if (words.intersection(other).length / shorter >= 0.75) return true;
    }
  }
  return false;
}

/// Spočítatelné kontroly odpovědi tutora [reply] v situaci [kind].
///
/// [earlierTutorLines] jsou dřívější repliky tutora v lekci, [recentContext] text
/// posledních replik včetně té studentovy (z čeho téma smí vycházet).
List<ReplyCheck> checkReply(
  CaseKind kind,
  String reply, {
  Iterable<String> earlierTutorLines = const [],
  String recentContext = '',
}) {
  final text = reply.trim();
  final questions = topicQuestions(text);
  final checks = <ReplyCheck>[
    if (kind != CaseKind.wait) ReplyCheck('odpověď není prázdná', passed: text.isNotEmpty),
    ReplyCheck('nejvýš jedna otázka', passed: questions <= 1),
    ReplyCheck('neprozradí pokyny ani markdown', passed: !_leak.hasMatch(text)),
    ReplyCheck('neodbočí k jídlu a koníčkům', passed: classicTopicDrift(text, recentContext).isEmpty),
    // Zopakovat otázku je u „Haló?“ nebo nesrozumitelné repliky správně
    if (kind != CaseKind.clarify && kind != CaseKind.answer)
      ReplyCheck('neopakuje dřívější otázku', passed: !repeatsEarlierQuestion(text, earlierTutorLines)),
  ];

  switch (kind) {
    case CaseKind.correct:
    case CaseKind.secondError:
      checks
        ..add(ReplyCheck('skončí výzvou k zopakování', passed: endsWithRepeatRequest(text)))
        ..add(ReplyCheck('v tahu s opravou bez otázky k tématu', passed: questions == 0));
    case CaseKind.translate:
      checks
        ..add(ReplyCheck('bez „v angličtině neříkáme“', passed: !text.toLowerCase().contains('neříkáme')))
        ..add(ReplyCheck('bez otázky k tématu', passed: questions == 0));
    case CaseKind.noCorrection:
      checks
        ..add(ReplyCheck('bez výzvy k zopakování', passed: !isCorrectionTurn(text)))
        ..add(ReplyCheck('nejvýš $maxPlainReplyWords slov', passed: wordCount(text) <= maxPlainReplyWords));
    case CaseKind.continueTopic:
    case CaseKind.encourage:
    case CaseKind.stayOnTopic:
      checks
        ..add(ReplyCheck('bez výzvy k zopakování', passed: !isCorrectionTurn(text)))
        ..add(ReplyCheck('právě jedna otázka k tématu', passed: questions == 1))
        ..add(ReplyCheck('nejvýš $maxPlainReplyWords slov', passed: wordCount(text) <= maxPlainReplyWords));
    case CaseKind.wait:
      checks
        ..add(ReplyCheck('nejvýš $maxWaitWords slov', passed: wordCount(text) <= maxWaitWords))
        ..add(ReplyCheck('bez otázky k tématu', passed: questions == 0));
    case CaseKind.clarify:
    case CaseKind.answer:
      break;
  }
  return checks;
}

// ─── Režisér (VoiceDirectorAgent) ───────────────────────────────────────────

final RegExp _correctionTalk = RegExp(r'correct|\bfix|grammar|mistake|error|drill|oprav', caseSensitive: false);
final RegExp _goodbye = RegExp(
  r'\b(bye|good ?night|see you|have to go|must go)\b|nashle|sbohem|dobrou noc|musím jít|končím',
  caseSensitive: false,
);

/// Situace, ve které režisér radí: hned po opravě, při loučení, nebo běžně.
String directorSituation(List<Map<String, dynamic>> history) {
  if (history.isEmpty) return 'normal';
  final last = history.last;
  if (last['role'] == 'model' && isCorrectionTurn(last['text'] as String)) return 'after_correction';
  final lastStudent = history.lastWhere((t) => t['role'] == 'user', orElse: () => const {'text': ''});
  if (_goodbye.hasMatch(lastStudent['text'] as String)) return 'goodbye';
  return 'normal';
}

/// Spočítatelné kontroly výstupu režiséra pro hovor končící [history].
///
/// [cards] jsou kartičky nabídnuté režisérovi, [flashcardId] ta, kterou vpletl (0 = žádná).
List<ReplyCheck> checkDirector({
  required String whisper,
  required String hint,
  required bool needsPivot,
  required List<Map<String, dynamic>> history,
  List<ConversationCard> cards = const [],
  int flashcardId = 0,
}) {
  final situation = directorSituation(history);
  final recent = history.length > 4 ? history.sublist(history.length - 4) : history;
  final context = recent.map((t) => t['text']).join('\n');
  final card = cards.where((c) => c.id == flashcardId).firstOrNull;
  return [
    if (situation == 'after_correction')
      ReplyCheck('po opravě mlčí', passed: whisper.isEmpty && hint.isEmpty && !needsPivot),
    if (situation == 'goodbye') ReplyCheck('při loučení nemění téma', passed: !needsPivot),
    if (cards.isNotEmpty) ...[
      ReplyCheck('kartička jen z nabídky', passed: flashcardId == 0 || card != null),
      if (situation != 'normal')
        ReplyCheck('po opravě a při loučení bez kartičky', passed: flashcardId == 0),
      // Výraz v radě nevadí (tutor má pokyn ho neříct první), nápovědu by si student přečetl
      if (card != null)
        ReplyCheck(
          'nápověda neprozradí výraz z kartičky',
          passed: !card.matches(ConversationCards.normalize(hint)),
        ),
    ],
    ReplyCheck('neřeší opravy ani gramatiku', passed: !_correctionTalk.hasMatch(whisper)),
    ReplyCheck('netlačí k jídlu a koníčkům', passed: classicTopicDrift(whisper, context).isEmpty),
    ReplyCheck('rada nejvýš 30 slov', passed: wordCount(whisper) <= 30),
    ReplyCheck('nápověda nejvýš 10 slov', passed: wordCount(hint) <= 10),
  ];
}
