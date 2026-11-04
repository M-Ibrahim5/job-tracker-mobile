import '../constants/account_strings.dart';
import '../constants/app_constants.dart';

/// Pure form validators; each returns an error message or null when valid.
abstract final class Validators {
  /// Required, trimmed, at most [max] characters.
  static String? requiredText(String? value, {int max = Limits.shortText}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return AppStrings.errRequired;
    if (v.length > max) return AppStrings.errMaxLength(max);
    return null;
  }

  /// Optional text with a maximum length.
  static String? optionalText(String? value, {required int max}) {
    final v = value?.trim() ?? '';
    return v.length > max ? AppStrings.errMaxLength(max) : null;
  }

  /// Optional http(s) URL.
  static String? optionalUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
    return ok ? null : AppStrings.errInvalidUrl;
  }

  /// Optional job description of at most [Limits.jobDescription] characters.
  static String? jobDescription(String? value) =>
      optionalText(value, max: Limits.jobDescription);

  /// Optional http(s) link of at most [Limits.linkLength] characters.
  static String? applicationLink(String? value) {
    if ((value?.trim().length ?? 0) > Limits.linkLength) {
      return AppStrings.errMaxLength(Limits.linkLength);
    }
    return optionalUrl(value);
  }

  /// Optional email address.
  static String? optionalEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    return ok ? null : AppStrings.errInvalidEmail;
  }

  /// Applied date may not be more than one day after [now].
  static String? appliedDate(DateTime? value, {DateTime? now}) {
    if (value == null) return AppStrings.errRequired;
    final limit = (now ?? DateTime.now()).add(const Duration(days: 1));
    return value.isAfter(limit) ? AppStrings.errFutureDate : null;
  }

  /// Required, well-formed email address.
  static String? requiredEmail(String? value) {
    if ((value?.trim() ?? '').isEmpty) return AppStrings.errRequired;
    return optionalEmail(value);
  }

  /// Password rules from `API.md`: at least 8 characters, a digit and a symbol.
  static String? newPassword(String? value) {
    final v = value ?? '';
    final ok =
        v.length >= 8 &&
        RegExp(r'\d').hasMatch(v) &&
        RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);
    return ok ? null : AccountStrings.errPasswordRules;
  }

  /// [value] must equal [original].
  static String? matches(String? value, String original) =>
      value == original ? null : AccountStrings.errPasswordMismatch;
}
