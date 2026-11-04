package com.jobtrail.tracker.reminders;

import com.jobtrail.common.reminder.ReminderText;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.time.TimeUtil;
import com.jobtrail.tracker.applications.ApplicationRepository;
import com.jobtrail.tracker.applications.ApplicationRow;
import com.jobtrail.tracker.interviews.InterviewRepository;
import com.jobtrail.tracker.interviews.InterviewRow;
import com.jobtrail.tracker.settings.ReminderPrefs;
import com.jobtrail.tracker.settings.UserSettingsClient;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Device reminders: the app schedules local notifications from this list. */
@RestController
@RequestMapping("/api/v1/reminders")
public class ReminderController {

  private static final Duration HORIZON = Duration.ofDays(60);

  public record Item(String key, String kind, Instant fireAt, String title, String body, long applicationId,
      Long interviewId) {}

  private final InterviewRepository interviews;
  private final ApplicationRepository applications;
  private final UserSettingsClient settings;

  public ReminderController(InterviewRepository interviews, ApplicationRepository applications,
      UserSettingsClient settings) {
    this.interviews = interviews;
    this.applications = applications;
    this.settings = settings;
  }

  @GetMapping("/upcoming")
  Map<String, List<Item>> upcoming(@CurrentUser long userId,
      @RequestHeader(value = "X-Timezone", required = false) String tz) {
    ZoneId zone = TimeUtil.zoneOrUtc(tz);
    Instant now = Instant.now();
    Instant horizon = now.plus(HORIZON);
    ReminderPrefs prefs = settings.prefsFor(userId);
    List<Item> items = new ArrayList<>();

    if (prefs.interviewRemindersEnabled()) {
      for (InterviewRow i : interviews.pendingAfter(userId, now)) {
        for (int offset : i.reminderOffsets()) {
          Instant fireAt = i.scheduledAt().minusSeconds(offset * 60L);
          if (!fireAt.isAfter(now) || fireAt.isAfter(horizon)) {
            continue;
          }
          items.add(new Item("interview:" + i.id() + ":" + offset, "interviewReminder", fireAt,
              ReminderText.interviewTitle(offset),
              ReminderText.interviewBody(i.companyName(), i.scheduledAt(), i.type(), zone),
              i.applicationId(), i.id()));
        }
      }
    }
    if (prefs.followUpRemindersEnabled()) {
      for (ApplicationRow a : applications.followUpsAfter(userId, now, horizon)) {
        items.add(new Item("followUp:" + a.id(), "followUpReminder", a.followUpAt(),
            ReminderText.followUpTitle(a.companyName()), a.jobTitle(), a.id(), null));
      }
    }
    items.sort(Comparator.comparing(Item::fireAt));
    return Map.of("items", items);
  }
}
