/// User-facing strings of the interviews feature.
abstract final class InterviewStrings {
  // List.
  static const listTitle = 'Interviews';
  static const tabUpcoming = 'Upcoming';
  static const tabPast = 'Past';
  static const fab = 'Interview';
  static const emptyUpcomingTitle = 'No upcoming interviews';
  static const emptyUpcomingMessage = 'Schedule one from an application.';
  static const emptyPastTitle = 'No past interviews';
  static const emptyPastMessage = 'Finished interviews will show up here.';
  static const loadMoreFailed = "Couldn't load more.";

  // Detail.
  static const detailTitle = 'Interview';
  static const edit = 'Edit';
  static const delete = 'Delete';
  static const application = 'Application';
  static const when = 'When';
  static const type = 'Type';
  static const duration = 'Duration';
  static const location = 'Location / link';
  static const interviewer = 'Interviewer';
  static const reminders = 'Reminders';
  static const noReminders = 'None';
  static const prepNotes = 'Prep notes';
  static const outcome = 'Outcome';
  static const openLink = 'Open link';
  static const linkOpenFailed = "Couldn't open the link";
  static const outcomeSaved = 'Outcome updated';
  static const deleteTitle = 'Delete interview?';
  static String deleteMessage(String title) =>
      'Delete "$title"? Its reminders are cancelled too.';
  static const deleted = 'Interview deleted';
  static String minutes(int n) => '$n min';

  // Form.
  static const newTitle = 'New interview';
  static const editTitle = 'Edit interview';
  static const fieldApplication = 'Application';
  static const fieldTitle = 'Title';
  static const fieldType = 'Type';
  static const fieldDate = 'Date';
  static const fieldTime = 'Time';
  static const fieldDuration = 'Duration';
  static const fieldLocation = 'Meeting link or address';
  static const fieldInterviewer = 'Interviewer';
  static const fieldRemind = 'Remind me';
  static const fieldNotes = 'Prep notes';
  static const pickApplication = 'Select an application';
  static const customReminder = 'Custom';
  static const customReminderTitle = 'Custom reminder';
  static const customReminderMinutes = 'Minutes before';
  static const customReminderAdd = 'Add';
  static const tooManyReminders = 'At most 5 reminders';
  static const pastWarning =
      'This time is in the past, so no reminders will be sent.';
  static const suggestTitle = 'Move to Interview?';
  static String suggestMessage(String company, String from) =>
      'Move $company from $from to Interview?';
  static const suggestYes = 'Yes, move it';
  static const suggestNo = 'Not now';
  static const discardTitle = 'Discard changes?';
  static const discardMessage = 'Your unsaved changes will be lost.';
  static const discardConfirm = 'Discard';
  static const saveFailed = "Couldn't save the interview.";
  static const formHasErrors = 'Please fix the highlighted fields.';
  static const statusMoveFailed =
      "Interview saved, but the status couldn't be changed.";
}
