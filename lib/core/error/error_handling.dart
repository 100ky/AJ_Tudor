/// Reprezentuje chybu v aplikaci, kterou můžeme zobrazit uživateli.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Chyba při komunikaci s API (např. Gemini).
class ApiFailure extends Failure {
  const ApiFailure(super.message, {super.code});
}

/// Chyba v databázi.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

/// Chyba týkající se hardware (mikrofon, audio).
class HardwareFailure extends Failure {
  const HardwareFailure(super.message, {super.code});
}

/// Neočekávaná chyba systému.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.code});
}

/// Výjimka, která se vyhazuje interně, pokud chceme přerušit tok a později ji převést na Failure.
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}
