/// User-facing strings of the dashboard and calendar.
abstract final class DashboardStrings {
  static const goodMorning = 'Good morning';
  static const goodAfternoon = 'Good afternoon';
  static const goodEvening = 'Good evening';
  static const addApplication = 'New application';
  static const statApplications = 'Applications';
  static const statActive = 'Active';
  static const statResponse = 'Response rate';
  static String responseSemantics(int percent) =>
      'Response rate $percent percent';
  static const sectionByStatus = 'By status';
  static const sectionPipeline = 'Pipeline';
  static const sectionWeekly = 'Applications per week';
  static const sectionUpcoming = 'Upcoming interviews';
  static const sectionActivity = 'Recent activity';
  static const seeAll = 'See all';
  static const thisWeek = 'This week';
  static const noUpcoming = 'No interviews coming up';
  static const noActivity = 'No status changes yet';
  static const emptyTitle = 'Start tracking your job search';
  static const emptyMessage =
      'Track where you applied, follow up on time and never miss an '
      'interview.';
  static const emptyAction = 'Add your first application';
  static String tileSemantics(String label, int count) =>
      '$label: $count applications';
  static String pipelineSummary(int total, List<String> parts) =>
      'Pipeline: $total applications. ${parts.join(', ')}.';
  static String barsSummary(List<String> counts) =>
      'Applications per week, last 8 weeks: ${counts.join(', ')}';
  static const weeklyCaption = 'Last 8 weeks';
  static const noWeeklyData = 'No applications in the last 8 weeks';
  static const addApplicationShort = 'Add application';
  static const pipelineEmptyCenter = 'No applications yet';
  static String legendSemantics(String label, int count, int percent) =>
      '$label, $count applications, $percent percent. Opens filtered list';
  static String weekSemantics(String weekLabel, int count) => count == 0
      ? 'Week of $weekLabel: no applications'
      : 'Week of $weekLabel: $count applications. Opens filtered list';
  static String shareOfTotal(int percent, int total) => '$percent% of $total';
  static const movedPrefix = 'Moved ';
  static const movedMiddle = ' to ';
}

/// User-facing strings of the calendar.
abstract final class CalendarStrings {
  static const title = 'Calendar';
  static const today = 'Today';
  static const previous = 'Previous';
  static const next = 'Next';
  static const formatMonth = 'Month';
  static const formatTwoWeeks = '2 weeks';
  static const formatWeek = 'Week';
  static const legendApplied = 'Applied';
  static const legendStatus = 'Status change';
  static const legendInterview = 'Interview';
  static const legendFollowUp = 'Follow-up';
  static String eventCount(int n) =>
      n == 0 ? 'No events' : (n == 1 ? '1 event' : '$n events');
  static const fab = 'Interview';
  static const loadFailed = "Couldn't load events.";
  static const jobTimeline = 'Job timeline';
  static const pickJob = 'Company';
  static const pickJobTitle = 'Choose an application';
  static const searchJobs = 'Search';
  static const noJobs = 'No applications found';
  static const clearTimeline = 'Clear job timeline';
  static const timelineEmpty = 'No history yet';
  static const upcomingMarker = 'Upcoming';
  static const sheetClose = 'Close';
  static const sheetEmptyTitle = 'Nothing scheduled';
  static const sheetEmptyMessage =
      'No interviews, follow-ups or application updates on this day.';
  static const addInterview = 'Add interview';
  static const addApplication = 'Add job application';
  static const typeInterview = 'Interview';
  static const typeFollowUp = 'Follow-up';
  static const typeStatusChange = 'Status change';
  static const typeApplied = 'Applied';
  static const allDay = 'All day';
  static String sheetLabel(String date) => 'Events on $date';
  static String movedTo(String status) => 'Moved to $status';
  static String viaSource(String source) => 'via $source';
}
