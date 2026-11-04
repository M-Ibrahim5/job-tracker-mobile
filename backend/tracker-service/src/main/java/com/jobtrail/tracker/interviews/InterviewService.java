package com.jobtrail.tracker.interviews;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.error.AppException;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.common.web.PageResponse;
import com.jobtrail.tracker.applications.ApplicationRepository;
import com.jobtrail.tracker.applications.ApplicationRow;
import com.jobtrail.tracker.notifications.ReminderSync;
import com.jobtrail.tracker.settings.ReminderPrefs;
import com.jobtrail.tracker.settings.UserSettingsClient;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.util.MultiValueMap;

@Service
public class InterviewService {

  public enum Scope {
    upcoming,
    past
  }

  private final InterviewRepository interviews;
  private final ApplicationRepository applications;
  private final ReminderSync reminders;
  private final UserSettingsClient settings;
  private final TransactionTemplate tx;

  public InterviewService(InterviewRepository interviews, ApplicationRepository applications,
      ReminderSync reminders, UserSettingsClient settings, TransactionTemplate tx) {
    this.interviews = interviews;
    this.applications = applications;
    this.reminders = reminders;
    this.settings = settings;
    this.tx = tx;
  }

  private static AppException conflict() {
    return new AppException("INTERVIEW_CONFLICT", HttpStatus.CONFLICT,
        "This application already has an interview at that time",
        Map.of("scheduledAt", "An interview is already scheduled at this time"));
  }

  private InterviewRow findOwned(long userId, long id) {
    return interviews.find(userId, id).orElseThrow(() -> AppException.notFound("Interview not found"));
  }

  public InterviewDto get(long userId, long id) {
    return InterviewDto.from(findOwned(userId, id));
  }

  public PageResponse<InterviewDto> list(long userId, MultiValueMap<String, String> params) {
    QueryParams q = new QueryParams(params);
    Scope scope = q.optionalEnum("scope", Scope.class);
    Long applicationId = q.optionalId("applicationId");
    String from = q.optionalDateOrDateTime("from");
    String to = q.optionalDateOrDateTime("to");
    int page = q.page();
    int pageSize = q.pageSize();
    q.finish();

    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    Instant lower = scope == Scope.upcoming ? now : null;
    Instant upper = scope == Scope.past ? now : null;
    // An explicit range overrides the scope's bound; a date-only `to` includes that whole day.
    if (from != null) {
      lower = QueryParams.parseInstantOrDate(from, false);
    }
    if (to != null) {
      upper = QueryParams.parseInstantOrDate(to, true);
    }
    InterviewRepository.Filter filter =
        new InterviewRepository.Filter(applicationId, lower, upper, scope == Scope.past);
    List<InterviewDto> items = interviews.list(userId, filter, pageSize, PageResponse.offset(page, pageSize))
        .stream().map(InterviewDto::from).toList();
    return new PageResponse<>(items, page, pageSize, interviews.count(userId, filter));
  }

  public InterviewDto create(long userId, long applicationId, JsonNode body, ZoneId zone) {
    InterviewInput input = InterviewInput.parse(body, true);
    applications.find(userId, applicationId, Instant.now())
        .orElseThrow(() -> AppException.notFound("Application not found"));
    ReminderPrefs prefs = settings.prefsFor(userId);
    List<Integer> offsets = input.reminderOffsets() != null
        ? input.reminderOffsets()
        : List.copyOf(new LinkedHashSet<>(prefs.defaultReminderOffsetsMinutes()));
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    try {
      Long id = tx.execute(status -> {
        long newId = interviews.insert(userId, applicationId, input.values(), offsets);
        reminders.syncInterview(userId, findOwned(userId, newId), zone, prefs, now);
        return newId;
      });
      return get(userId, id);
    } catch (DuplicateKeyException e) {
      throw conflict();
    }
  }

  public InterviewDto update(long userId, long id, JsonNode body, ZoneId zone) {
    InterviewInput input = InterviewInput.parse(body, false);
    findOwned(userId, id);
    ReminderPrefs prefs = settings.prefsFor(userId);
    Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
    try {
      tx.executeWithoutResult(status -> {
        interviews.update(id, input.values(), input.reminderOffsets());
        reminders.syncInterview(userId, findOwned(userId, id), zone, prefs, now);
      });
    } catch (DuplicateKeyException e) {
      throw conflict();
    }
    return get(userId, id);
  }

  public void delete(long userId, long id) {
    if (interviews.delete(userId, id) == 0) {
      throw AppException.notFound("Interview not found");
    }
  }
}
