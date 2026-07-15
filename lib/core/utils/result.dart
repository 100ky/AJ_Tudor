import '../error/error_handling.dart';

/// Wrapper pro výsledek operace, který může být buď úspěšný (S) nebo selhat (Failure).
abstract class Result<S> {
  const Result();

  /// Vytvoří úspěšný výsledek.
  const factory Result.success(S value) = Success<S>;

  /// Vytvoří neúspěšný výsledek.
  const factory Result.failure(Failure failure) = Error<S>;

  bool get isSuccess => this is Success<S>;
  bool get isFailure => this is Error<S>;

  /// Transformuje výsledek na základě stavu.
  T fold<T>(T Function(S value) onSuccess, T Function(Failure failure) onFailure) {
    if (this is Success<S>) {
      return onSuccess((this as Success<S>).value);
    } else {
      return onFailure((this as Error<S>).failure);
    }
  }

  /// Vrátí hodnotu, nebo vyhodí chybu, pokud se jedná o Failure.
  S getOrThrow() {
    if (this is Success<S>) {
      return (this as Success<S>).value;
    } else {
      throw (this as Error<S>).failure;
    }
  }
}

class Success<S> extends Result<S> {
  final S value;
  const Success(this.value);
}

class Error<S> extends Result<S> {
  final Failure failure;
  const Error(this.failure);
}
