package com.jobtrail.tracker.applications;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.error.AppException;
import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.NotificationType;
import com.jobtrail.common.reminder.ReminderText;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.common.web.PageResponse;
import com.jobtrail.tracker.history.HistoryDto;
import com.jobtrail.tracker.history.HistoryRepository;
import com.jobtrail.tracker.history.HistoryRow;
import com.jobtrail.tracker.interviews.InterviewDto;
import com.jobtrail.tracker.interviews.InterviewRepository;
import com.jobtrail.tracker.notifications.NewNotification;
import com.jobtrail.tracker.notifications.NotificationRepository;
import com.jobtrail.tracker.notifications.ReminderSync;
import com.jobtrail.tracker.settings.ReminderPrefs;
import com.jobtrail.tracker.settings.UserSettingsClient;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.util.MultiValueMap;

@Service
public class ApplicationService {

  public record StatusChangeResult(ApplicationDto application, HistoryDto history) {}

  public record Timeline(List<HistoryDto> history, List<InterviewDto> interviews) {}

  private final ApplicationRepository applications;
  private final HistoryRepository history;
  private final InterviewRepository interviews;
  private final NotificationRepository notifications;
  private final ReminderSync reminders;
  private final UserSettingsClient settings;
  private final TransactionTemplate tx;

  public ApplicationService(ApplicationRepository applications, HistoryRepository history,
      InterviewRepository interviews, NotificationRepository notifications, ReminderSync reminders,
      UserSettingsClient settings, TransactionTemplate tx) {
    this.applications = applications;
    this.history = history;
    this.interviews = interviews;
    this.notifications = notifications;
    this.reminders = reminders;
    this.settings = settings;
    this.tx = tx;
  }

  /** Loads an application owned by the user or throws 404 (never reveals other users' ids). */
  private ApplicationRow findOwned(long userId, long id) {
    return applications.find(userId, id, Instant.now())
        .orElseThrow(() -> AppException.notFound("Application not found"));
  }

  public ApplicationDto get(long userId, long id) {
    return ApplicationDto.from(findOwned(userId, id));
  }

  public PageResponse<ApplicationDto> list(long userId, MultiValueMap<String, String> params) {
    QueryParams q = new QueryParams(params);
    String text = q.text("q");
    var status = q.enumList("status", ApplicationStatus.class);
    var arrangement = q.enumList("arrangement", com.jobtrail.common.model.WorkArrangement.class);
    LocalDate from = q.optionalDate("from");
    LocalDate to = q.optionalDate("to");
    ApplicationRepository.Sort sort = q.optionalEnum("sort", ApplicationRepository.Sort.class);
    int page = q.page();
    int pageSize = q.pageSize();
    q.finish();

    var filter = new ApplicationRepository.Filter(text, status, arrangement, from, to,
        sort == null ? ApplicationRepository.Sort.newest : sort);
    List<ApplicationDto> items = applications
        .list(userId, filter, pageSize, PageResponse.offset(page, pageSize), Instant.now()).stream()
        .map(ApplicationDto::from)
        .toList();
    return new PageResponse<>(items, page, pageSize, applications.count(userId, filter));
  }

  public ApplicationDto create(long userId, JsonNode body) {
    Map<String, Object> values = ApplicationInput.parse(body, true);
    ReminderPrefs prefs = settings.prefsFor(userId);
    ApplicationStatus status = (ApplicationStatus) values.get("status");
    Instant followUpAt = (Instant) values.get("followUpAt");
    // Omitted follow-up: apply the user's default; an explicit null opts out.
    if (!values.containsKey("followUpAt") && prefs.defaultFollowUpDays() != null) {
      LocalDate due = ((LocalDate) values.get("appliedDate")).plusDays(prefs.defaultFollowUpDays());
      followUpAt = due.atTime(9, 0).toInstant(ZoneOffset.UTC);
    }
    Instant resolvedFollowUp = followUpAt;
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    Long id = tx.execute(s -> {
      long newId = applications.insert(userId, values, status, resolvedFollowUp);
      history.insert(userId, newId, null, status, now, null);
      reminders.syncFollowUp(userId, newId, (String) values.get("companyName"), (String) values.get("jobTitle"),
          resolvedFollowUp, prefs, now);
      return newId;
    });
    return get(userId, id);
  }

  public ApplicationDto update(long userId, long id, JsonNode body) {
    Map<String, Object> values = ApplicationInput.parse(body, false);
    findOwned(userId, id);
    // The reminder text embeds company and title, so any of these changes needs a refresh.
    boolean reminderChanged = values.containsKey("followUpAt") || values.containsKey("companyName")
        || values.containsKey("jobTitle");
    ReminderPrefs prefs = reminderChanged ? settings.prefsFor(userId) : null;
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    tx.executeWithoutResult(s -> {
      applications.update(id, values);
      if (reminderChanged) {
        ApplicationRow after = findOwned(userId, id);
        reminders.syncFollowUp(userId, id, after.companyName(), after.jobTitle(), after.followUpAt(), prefs, now);
      }
    });
    return get(userId, id);
  }

  public void delete(long userId, long id) {
    if (applications.delete(userId, id) == 0) {
      throw AppException.notFound("Application not found");
    }
  }

  public StatusChangeResult changeStatus(long userId, long id, JsonNode body) {
    ApplicationInput.StatusChange change = ApplicationInput.parseStatusChange(body);
    ApplicationRow existing = findOwned(userId, id);
    if (existing.status() == change.status()) {
      // No-op: same status, no history row.
      HistoryDto latest = history.latest(userId, id).map(HistoryDto::from).orElse(null);
      return new StatusChangeResult(ApplicationDto.from(existing), latest);
    }
    ReminderPrefs prefs = settings.prefsFor(userId);
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    HistoryRow entry = tx.execute(s -> {
      applications.updateStatus(id, change.status());
      long historyId = history.insert(userId, id, existing.status(), change.status(), now, change.note());
      if (prefs.statusAlertsEnabled()) {
        notifications.insert(new NewNotification(userId, NotificationType.statusChange,
            ReminderText.statusChangeTitle(change.status().label()),
            ReminderText.statusChangeBody(existing.companyName(), existing.jobTitle()), id, null, now));
      }
      return history.get(historyId);
    });
    return new StatusChangeResult(get(userId, id), HistoryDto.from(entry));
  }

  public List<HistoryDto> history(long userId, long id) {
    findOwned(userId, id);
    return history.forApplication(userId, id).stream().map(HistoryDto::from).toList();
  }

  public Timeline timeline(long userId, long id) {
    List<HistoryDto> entries = history(userId, id);
    List<InterviewDto> items = interviews.forApplication(userId, id).stream().map(InterviewDto::from).toList();
    return new Timeline(entries, items);
  }
}
