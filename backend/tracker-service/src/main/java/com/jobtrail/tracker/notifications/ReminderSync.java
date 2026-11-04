package com.jobtrail.tracker.notifications;

import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.NotificationType;
import com.jobtrail.common.reminder.ReminderText;
import com.jobtrail.tracker.interviews.InterviewRow;
import com.jobtrail.tracker.settings.ReminderPrefs;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Keeps reminder notification rows in step with interviews and follow-ups: unfired rows are
 * replaced, rows whose time has passed are history and never touched. Call inside the caller's
 * transaction.
 */
@Component
public class ReminderSync {

  private final NotificationRepository notifications;

  public ReminderSync(NotificationRepository notifications) {
    this.notifications = notifications;
  }

  public void syncInterview(long userId, InterviewRow interview, ZoneId zone, ReminderPrefs prefs, Instant now) {
    notifications.deleteUnfiredInterviewReminders(userId, interview.id(), now);
    // Only pending interviews remind: cancelled, passed or failed ones have nothing left to prepare for.
    if (!prefs.interviewRemindersEnabled() || interview.outcome() != InterviewOutcome.pending) {
      return;
    }
    List<NewNotification> rows = new ArrayList<>();
    for (int offset : interview.reminderOffsets()) {
      Instant fireAt = interview.scheduledAt().minusSeconds(offset * 60L);
      if (fireAt.isAfter(now)) {
        rows.add(new NewNotification(userId, NotificationType.interviewReminder,
            ReminderText.interviewTitle(offset),
            ReminderText.interviewBody(interview.companyName(), interview.scheduledAt(), interview.type(), zone),
            interview.applicationId(), interview.id(), fireAt));
      }
    }
    notifications.insertAll(rows);
  }

  public void syncFollowUp(long userId, long applicationId, String companyName, String jobTitle,
      Instant followUpAt, ReminderPrefs prefs, Instant now) {
    notifications.deleteUnfiredFollowUpReminders(userId, applicationId, now);
    if (!prefs.followUpRemindersEnabled() || followUpAt == null || !followUpAt.isAfter(now)) {
      return;
    }
    notifications.insert(new NewNotification(userId, NotificationType.followUpReminder,
        ReminderText.followUpTitle(companyName), jobTitle, applicationId, null, followUpAt));
  }
}
