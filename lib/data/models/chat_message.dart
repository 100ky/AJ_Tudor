/// Třída reprezentující konkrétní opravenou chybu v promluvě uživatele.
class ChatMessageCorrection {
  /// Původní chybný tvar / slovo, které student řekl či napsal.
  final String userSaid;

  /// Správný gramatický či lexikální tvar.
  final String correctForm;

  /// Stručné vysvětlení pravidla v češtině.
  final String explanation;

  /// Typ chyby ('grammar' | 'vocabulary' | 'pronunciation' | 'preposition' | 'tense').
  final String errorType;

  const ChatMessageCorrection({
    required this.userSaid,
    required this.correctForm,
    required this.explanation,
    this.errorType = 'grammar',
  });

  Map<String, dynamic> toJson() => {
        'userSaid': userSaid,
        'correctForm': correctForm,
        'explanation': explanation,
        'errorType': errorType,
      };

  factory ChatMessageCorrection.fromJson(Map<String, dynamic> json) =>
      ChatMessageCorrection(
        userSaid: json['userSaid']?.toString() ?? '',
        correctForm: json['correctForm']?.toString() ?? '',
        explanation: json['explanation']?.toString() ?? '',
        errorType: json['errorType']?.toString() ?? 'grammar',
      );
}

/// Třída reprezentující jednotlivou zprávu v historii chatu nebo hlasového sezení.
class ChatMessage {
  /// Samotný text zprávy.
  final String text;

  /// Příznak, zda zprávu poslal uživatel/student ([true]), nebo tutor ([false]).
  final bool isUser;

  /// Čas odeslání zprávy.
  final DateTime timestamp;

  /// Volitelný seznam detekovaných a opravených chyb pro chytré bubliny.
  final List<ChatMessageCorrection>? corrections;

  /// Volitelná celá opravená věta (pokud existují chyby).
  final String? correctedSentence;

  /// Vytvoří instanci zprávy.
  ChatMessage(
    this.text, {
    required this.isUser,
    DateTime? timestamp,
    this.corrections,
    this.correctedSentence,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Určuje, zda tato zpráva obsahuje nějaké evidované opravy chyb.
  bool get hasCorrections => corrections != null && corrections!.isNotEmpty;

  /// Vytvoří kopii zprávy s aktualizovanými opravami.
  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<ChatMessageCorrection>? corrections,
    String? correctedSentence,
  }) {
    return ChatMessage(
      text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      corrections: corrections ?? this.corrections,
      correctedSentence: correctedSentence ?? this.correctedSentence,
    );
  }
}

