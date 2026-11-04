/// Typed failures surfaced by repositories and services.
sealed class Failure implements Exception {
  /// Creates a failure with a developer-facing [message].
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server answered with an error body (`API.md` error envelope).
class ApiFailure extends Failure {
  /// Creates an API failure.
  const ApiFailure({
    required this.code,
    required String message,
    this.fields = const {},
    this.statusCode,
  }) : super(message);

  /// Machine code such as `VALIDATION_ERROR` or `EMAIL_TAKEN`.
  final String code;

  /// Per-field validation messages keyed by JSON field name.
  final Map<String, String> fields;
  final int? statusCode;
}

/// The server could not be reached (offline, timeout, DNS, TLS).
class NetworkFailure extends Failure {
  /// Creates a network failure.
  const NetworkFailure([super.message = 'Network unreachable']);
}

/// The session is no longer valid; the user must sign in again.
class UnauthorizedFailure extends Failure {
  /// Creates an unauthorized failure.
  const UnauthorizedFailure([super.message = 'Session expired']);
}

/// Storage on the device failed (secure storage, temp files).
class StorageFailure extends Failure {
  /// Creates a storage failure.
  const StorageFailure(super.message);
}

/// Well-known [ApiFailure.code] values from `API.md`.
abstract final class ApiCodes {
  static const validation = 'VALIDATION_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const interviewConflict = 'INTERVIEW_CONFLICT';
  static const emailTaken = 'EMAIL_TAKEN';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const rateLimited = 'RATE_LIMITED';
  static const internal = 'INTERNAL';
}
