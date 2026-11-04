/// Strength buckets shown by the 4-segment meter.
enum PasswordStrength {
  empty('', 0),
  weak('Weak', 1),
  fair('Fair', 2),
  good('Good', 3),
  strong('Strong', 4);

  const PasswordStrength(this.label, this.segments);

  /// Text shown next to the meter.
  final String label;

  /// Number of filled meter segments (0–4).
  final int segments;
}

/// Rates [password]: one point each for length ≥ 8, a digit, a symbol and
/// mixed case. Anything shorter than 8 characters stays Weak.
PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  if (password.length < 8) return PasswordStrength.weak;
  final mixedCase =
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password);
  final points =
      1 +
      (RegExp(r'\d').hasMatch(password) ? 1 : 0) +
      (RegExp(r'[^A-Za-z0-9\s]').hasMatch(password) ? 1 : 0) +
      (mixedCase ? 1 : 0);
  return switch (points) {
    1 => PasswordStrength.weak,
    2 => PasswordStrength.fair,
    3 => PasswordStrength.good,
    _ => PasswordStrength.strong,
  };
}
