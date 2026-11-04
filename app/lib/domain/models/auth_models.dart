import 'user.dart';

/// Access + refresh token pair.
class AuthTokens {
  /// Creates a token pair.
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// Parses `{ accessToken, refreshToken }`.
  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );

  final String accessToken;
  final String refreshToken;
}

/// Response of register / login.
class AuthResponse {
  /// Creates an auth response.
  const AuthResponse({required this.tokens, required this.user});

  /// Parses an `AuthResponse`.
  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    tokens: AuthTokens.fromJson(json),
    user: User.fromJson(json['user'] as Map<String, dynamic>),
  );

  final AuthTokens tokens;
  final User user;
}
