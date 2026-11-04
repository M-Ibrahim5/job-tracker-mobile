/// Central place for user-facing strings and tunable constants.
/// Structured so it can be swapped for `l10n` ARB files later.
abstract final class AppStrings {
  static const appName = 'JobTrail';

  static const tabDashboard = 'Dashboard';
  static const tabApplications = 'Applications';
  static const tabCalendar = 'Calendar';
  static const tabNotifications = 'Alerts';
  static const tabSettings = 'Settings';

  static const comingSoon = 'Coming in an upcoming session';
  static const retry = 'Retry';
  static const cancel = 'Cancel';
  static const delete = 'Delete';
  static const save = 'Save';
  static const undo = 'Undo';
  static const ok = 'OK';
  static const required = 'required';

  // Placeholder screens.
  static const screenOnboarding = 'Welcome';
  static const screenNewApplication = 'New application';
  static const screenEditApplication = 'Edit application';
  static const screenApplicationDetail = 'Application';
  static const screenInterviews = 'Interviews';
  static const screenInterviewDetail = 'Interview';
  static const screenNewInterview = 'New interview';
  static const screenEditInterview = 'Edit interview';
  static const screenEditProfile = 'Edit profile';

  // Validation.
  static const errRequired = 'This field is required';
  static const errInvalidUrl = 'Enter a valid http(s) link';
  static const errInvalidEmail = 'Enter a valid email address';
  static const errFutureDate = 'Date cannot be more than 1 day in the future';
  static String errMaxLength(int n) => 'Maximum $n characters';

  // Failures.
  static const errNetwork =
      'Can\'t reach the server. Check your connection and try again.';
  static const errSessionExpired =
      'Your session expired. Please sign in again.';
  static const errInvalidCredentials = 'Incorrect email or password.';
  static const errEmailTaken = 'An account with this email already exists.';
  static const errInterviewConflict =
      'You already have an interview at this time for this application.';
  static const errRateLimited = 'Too many attempts. Please wait a moment.';
  static const errNotFound = 'We couldn\'t find that item.';
  static const errStorage = 'Couldn\'t access secure storage on this device.';
  static const errGeneric = 'Something went wrong. Please try again.';

  // Shared widgets.
  static const emptyDefaultTitle = 'Nothing here yet';
  static const errorDefaultTitle = 'Something went wrong';
  static const loading = 'Loading';
  static const optionalMarker = 'Optional';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static String unreadSemantics(int n) => '$n unread';
}

/// Spacing scale (4/8/12/16/24).
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Horizontal padding of every screen.
  static const double screen = 20;

  /// Gap between sections of a screen.
  static const double section = 24;
}

/// Corner radii from `DESIGN.md §2`.
abstract final class Radii {
  static const double card = 18;
  static const double summary = 24;
  static const double input = 14;
  static const double button = 16;
  static const double chip = 12;
  static const double fab = 18;
}

/// Fixed component sizes.
abstract final class Sizes {
  static const double buttonHeight = 54;
  static const double navBarHeight = 64;
  static const double minTouch = 48;
  static const double chipHeight = 40;
}

/// Field limits from the product spec.
abstract final class Limits {
  static const shortText = 100;
  static const jobDescription = 10000;
  static const linkLength = 2048;
  static const note = 500;
}
