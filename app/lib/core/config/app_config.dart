/// Build-time configuration, supplied with `--dart-define`.
abstract final class AppConfig {
  /// REST API root. The default reaches the dev machine through
  /// `adb reverse tcp:3000 tcp:3000` (works for emulators and USB phones;
  /// `run-dev.ps1` sets it up). Override with `--dart-define=API_BASE_URL=...`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Use the in-memory fake backend instead of the REST API.
  static const useFakeBackend = bool.fromEnvironment('USE_FAKE');

  /// Lets a release build talk to a plain-http API (local testing only).
  static const allowInsecureApi = bool.fromEnvironment('ALLOW_INSECURE_API');

  /// Problem with [apiBaseUrl] for a release build, or null when it is fine.
  /// Tokens and passwords must never travel over plain http in production.
  static String? releaseUrlProblem({
    String url = apiBaseUrl,
    bool fake = useFakeBackend,
    bool allowInsecure = allowInsecureApi,
  }) {
    if (fake || allowInsecure || url.startsWith('https://')) return null;
    return 'API_BASE_URL must use https:// in release builds (got $url). '
        'Pass --dart-define=API_BASE_URL=https://... or, for local testing '
        'only, --dart-define=ALLOW_INSECURE_API=true.';
  }

  /// Network timeouts.
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
