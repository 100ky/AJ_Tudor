/// Třída reprezentující jednotlivou zprávu v historii chatu.
class ChatMessage {
  /// Samotný text zprávy.
  final String text;
  /// Příznak, zda zprávu poslal uživatel/student ([true]), nebo tutor ([false]).
  final bool isUser;

  /// Vytvoří instanci zprávy.
  ChatMessage(this.text, {required this.isUser});
}
