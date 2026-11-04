/// User-facing strings of the applications feature.
abstract final class ApplicationStrings {
  // List.
  static const listTitle = 'Applications';
  static String total(int n) => '$n total';
  static const searchHint = 'Search title, company or location';
  static const searchSemantics = 'Search applications';
  static const filterButton = 'Filter and sort';
  static const filterAll = 'All';
  static const addFab = 'Add';
  static String sortedBy(String label) => 'Sorted by ${label.toLowerCase()}';
  static const emptyTitle = 'No applications yet';
  static const emptyMessage =
      'Track every job you apply for in one place. Add your first one.';
  static const emptyAction = 'Add application';
  static const noResultsTitle = 'No results';
  static const noResultsMessage = 'Nothing matches your search or filters.';
  static const clearFilters = 'Clear filters';
  static const clearFilter = 'Clear filter';
  static const clearAll = 'Clear all';
  static String noStatusTitle(String status) => 'No $status applications yet';
  static const noStatusMessage = 'Nothing is at this stage right now.';
  static String statusChip(String statuses) => 'Status: $statuses';
  static String arrangementChip(String arrangements) => 'Work: $arrangements';
  static String removeFilter(String label) => 'Remove filter $label';
  static const activeFilters = 'Active filters';
  static const loadMoreFailed = "Couldn't load more.";
  static String nextInterview(String date) => 'Next: $date';
  static String followUpOn(String date) => 'Follow up $date';

  // Filter sheet.
  static const filterTitle = 'Filter & sort';
  static const filterStatus = 'Status';
  static const filterArrangement = 'Work arrangement';
  static const filterDates = 'Applied between';
  static const filterFrom = 'From';
  static const filterTo = 'To';
  static const filterAnyDate = 'Any';
  static const filterClearDates = 'Clear dates';
  static const filterSort = 'Sort by';
  static const filterApply = 'Apply';
  static const filterReset = 'Reset';

  // Swipe / delete.
  static const swipeStatus = 'Status';
  static const swipeDelete = 'Delete';
  static const deleteTitle = 'Delete application?';
  static String deleteMessage(String title, String company) =>
      'Delete "$title" at $company? Its history and interviews are removed too.';
  static const deleteUpcomingWarning =
      ' It has upcoming interviews, and their reminders will be cancelled.';
  static const deleted = 'Application deleted';
  static const deleteFailed = "Couldn't delete the application.";

  // Status sheet.
  static const statusSheetTitle = 'Change status';
  static const statusCurrent = 'Current';
  static const statusNext = 'Next step';
  static const statusNoteLabel = 'Note (optional)';
  static const statusNoteHint = 'e.g. Recruiter called';
  static const statusConfirm = 'Confirm';
  static String statusChanged(String label) => 'Moved to $label';
  static const statusChangeFailed = "Couldn't change the status.";

  // Message shown after the status changes to offer / rejected.
  static const offerTitle = 'Congratulations! 🎉';
  static String offerMessage(String company) =>
      'You got an offer from $company! All your hard work paid off. '
      'Take a moment to celebrate this win — you earned it.';
  static const offerAction = 'Thank you!';
  static const rejectedTitle = "Don't be discouraged";
  static String rejectedMessage(String company) =>
      '$company went another way this time, but that says nothing about your '
      'worth. Every application teaches you something — the right role is '
      'still out there, and you are closer than you think.';
  static const rejectedAction = 'Keep going';

  // Detail.
  static const detailEdit = 'Edit';
  static const detailDelete = 'Delete';
  static const actionOpenLink = 'Open link';
  static const actionInterview = 'Interview';
  static const actionFollowUp = 'Follow-up';
  static const noLinkSaved = 'No link saved for this application';
  static const linkOpenFailed = "Couldn't open the link";
  static const mailOpenFailed = "Couldn't open your email app";
  static const sectionStatus = 'Status';
  static const statusHelper =
      'Dashed outline marks the next step in the usual flow. '
      'Any status can be set at any time.';
  static const sectionTimeline = 'Status timeline';
  static const sectionInterviews = 'Interviews';
  static const addInterview = 'Add';
  static const noInterviews = 'No interviews yet';
  static const sectionDescription = 'Job description';
  static const readMore = 'Read more';
  static const readLess = 'Show less';
  static const sectionDetails = 'Details';
  static const sectionNotes = 'Notes';
  static const detailAppliedOn = 'Applied on';
  static const detailSource = 'Source';
  static const detailContact = 'Contact';
  static const detailFollowUp = 'Follow-up';
  static const notSet = 'Not set';
  static String timelineFirst(String date, String? source) =>
      source == null ? 'Applied · $date' : 'Applied · $date · via $source';
  static String timelineChange(String from, String to) => '$from → $to';
  static const followUpChange = 'Change date';
  static const followUpClear = 'Clear follow-up';
  static const followUpSaved = 'Follow-up date saved';
  static const followUpCleared = 'Follow-up cleared';
  static const updateFailed = "Couldn't save the change.";

  // Form.
  static const newTitle = 'New application';
  static const editTitle = 'Edit application';
  static const closeForm = 'Close';
  static const fieldJobTitle = 'Job title';
  static const fieldCompany = 'Company';
  static const fieldLocation = 'Location';
  static const fieldArrangement = 'Work arrangement';
  static const fieldEmploymentType = 'Employment type';
  static const fieldAppliedDate = 'Applied date';
  static const fieldSource = 'Source';
  static const fieldSalary = 'Salary range';
  static const fieldLink = 'Application link';
  static const fieldDescription = 'Job description';
  static const fieldContactName = 'Contact name';
  static const fieldContactEmail = 'Contact email';
  static const fieldNotes = 'Notes';
  static const sourceNone = 'Not specified';
  static const followUpSwitchTitle = 'Follow-up reminder';
  static String followUpSwitchSubtitle(String date) =>
      'Remind me on $date if no reply';
  static const followUpOffHint =
      'Set a default follow-up in Settings to enable this';
  static const discardTitle = 'Discard changes?';
  static const discardMessage = 'Your unsaved changes will be lost.';
  static const discardConfirm = 'Discard';
  static const saveFailed = "Couldn't save the application.";
  static const formHasErrors = 'Please fix the highlighted fields.';
  static const loadFailed = "Couldn't load the application.";
}
