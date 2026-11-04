/// User-facing text for auth, settings and profile screens.
abstract final class AccountStrings {
  // Shared field labels.
  static const email = 'Email';
  static const password = 'Password';
  static const fullName = 'Full name';
  static const confirmPassword = 'Confirm password';

  // Login.
  static const loginTitle = 'Welcome back';
  static const loginSubtitle = 'Sign in to keep your job search on track.';
  static const signIn = 'Sign in';
  static const forgotPassword = 'Forgot password?';
  static const newToApp = 'New to JobTrail? ';
  static const createAccountLink = 'Create account';
  static const errPasswordRequired = 'Enter your password';

  // Fingerprint login.
  static const biometricSignIn = 'Sign in with fingerprint';
  static const biometricSignInReason = 'Scan your fingerprint to sign in';
  static const biometricEnableReason =
      'Scan your fingerprint to turn on fingerprint login';
  static const biometricTitle = 'Fingerprint login';
  static const biometricSubtitle = 'Sign in with your fingerprint, no password';
  static const biometricEnabled = 'Fingerprint login is on';
  static const biometricDisabled = 'Fingerprint login is off';
  static const biometricPasswordTitle = 'Confirm your password';
  static const biometricPasswordBody =
      'Enter your password once to link this phone. It is not stored: the '
      'phone keeps a secret key that only opens after your fingerprint.';
  static const biometricPasswordAction = 'Turn on';
  static const biometricExpired =
      'Fingerprint login expired. Sign in with your password, then turn it '
      'on again.';

  // Forgot password.
  static const forgotTitle = 'Reset your password';
  static const forgotBody = 'Enter your email and we will send a reset link.';
  static const forgotSend = 'Send link';
  static const forgotSent = 'If that email exists, we sent a link';

  // Register.
  static const registerTitle = 'Create your account';
  static const passwordHint =
      'At least 8 characters with a number and a symbol';
  static const terms = 'I agree to the Terms and Privacy Policy';
  static const createAccount = 'Create account';
  static const haveAccount = 'Already have an account? ';
  static const back = 'Back';
  static const errPasswordRules =
      'Use at least 8 characters with a number and a symbol';
  static const errPasswordMismatch = 'Passwords do not match';

  // Settings.
  static const settingsTitle = 'Settings';
  static const editProfile = 'Edit profile';
  static const sectionAccount = 'Account';
  static const personalDetails = 'Personal details';
  static const changePassword = 'Change password';
  static const sectionAppearance = 'Appearance';
  static const sectionNotifications = 'Notifications';
  static const interviewReminders = 'Interview reminders';
  static const followUpReminders = 'Follow-up reminders';
  static const statusChanges = 'Status changes';
  static const defaultReminders = 'Default interview reminders';
  static const defaultFollowUp = 'Default follow-up after';
  static const followUpOff = 'Off';
  static String followUpDays(int d) => '$d days';
  static String reminderOffset(Duration d) => switch (d.inMinutes) {
    1440 => '1 day',
    60 => '1 hour',
    15 => '15 min',
    final m when m % 1440 == 0 => '${m ~/ 1440} days',
    final m when m % 60 == 0 => '${m ~/ 60} hours',
    final m => '$m min',
  };
  static const sectionData = 'Data';
  static const exportData = 'Export data';
  static const exportJson = 'Export as JSON';
  static const exportCsv = 'Export as CSV';
  static const exportFailed = 'Could not export your data.';
  static const deleteAllData = 'Delete all data';
  static const deleteAllTitle = 'Delete everything?';
  static const deleteAllBody =
      'This removes all applications, interviews and alerts. Your account '
      'stays.';
  static const deleteAllTypeTitle = 'Type DELETE to confirm';
  static const deleteConfirmWord = 'DELETE';
  static const deleteAllDone = 'All data deleted';
  static const sectionAbout = 'About';
  static const aboutApp = 'About JobTrail';
  static String version(String v) => 'Version $v';
  static const logOut = 'Log out';
  static const logOutTitle = 'Log out?';
  static const logOutBody = 'You will need to sign in again.';
  static String signedInAs(String email) => 'Signed in as $email';
  static const settingsSaveFailed = 'Could not save your settings.';

  // Change password.
  static const currentPassword = 'Current password';
  static const newPassword = 'New password';
  static const confirmNewPassword = 'Confirm new password';
  static const passwordChanged = 'Password changed';
  static const errCurrentPasswordWrong = 'Current password is incorrect';

  // Edit profile.
  static const changePhoto = 'Change photo';
  static const emailReadOnlyHint = 'Email cannot be changed';
  static const verified = 'Verified';
  static const phone = 'Phone';
  static const currentRole = 'Current role';
  static const lookingFor = 'Looking for';
  static const location = 'Location';
  static const profileSaved = 'Profile updated';
  static const discardTitle = 'Discard changes?';
  static const discardBody = 'Your edits have not been saved.';
  static const discard = 'Discard';
  static const keepEditing = 'Keep editing';
  static const deleteAccount = 'Delete account';
  static const deleteAccountTitle = 'Delete your account?';
  static const deleteAccountBody =
      'This permanently deletes your account and all of your data. Enter your '
      'password to confirm.';
  static const accountDeleted = 'Account deleted';
  static const semBack = 'Back';
  static const photoUnsupported = 'Choose a JPEG or PNG image under 2 MB.';
  static const semChangePhoto = 'Change profile photo';
}
