/// Route paths, centralized (`DESIGN.md §5`).
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';

  static const dashboard = '/';
  static const applications = '/applications';
  static const calendar = '/calendar';
  static const notifications = '/notifications';
  static const settings = '/settings';

  static const newApplication = '/applications/new';
  static const interviews = '/interviews';
  static const newInterview = '/interviews/new';
  static const editProfile = '/settings/profile';

  static String applicationDetail(int id, {int? focusInterview}) =>
      focusInterview == null
      ? '/applications/$id'
      : '/applications/$id?focusInterview=$focusInterview';
  static String editApplication(int id) => '/applications/$id/edit';
  static String newInterviewFor(int applicationId) =>
      '/applications/$applicationId/interviews/new';
  static String interviewDetail(int id) => '/interviews/$id';
  static String editInterview(int id) => '/interviews/$id/edit';
}
