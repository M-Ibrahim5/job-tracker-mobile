package com.jobtrail.tracker.calendar;

import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.time.Iso;
import com.jobtrail.common.time.TimeUtil;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.tracker.applications.ApplicationRepository;
import com.jobtrail.tracker.applications.ApplicationRow;
import com.jobtrail.tracker.history.HistoryRepository;
import com.jobtrail.tracker.interviews.InterviewRepository;
import com.jobtrail.tracker.interviews.InterviewRow;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/calendar")
public class CalendarController {

  private static final int MAX_RANGE_DAYS = 70;

  private final ApplicationRepository applications;
  private final HistoryRepository history;
  private final InterviewRepository interviews;

  public CalendarController(ApplicationRepository applications, HistoryRepository history,
      InterviewRepository interviews) {
    this.applications = applications;
    this.history = history;
    this.interviews = interviews;
  }

  @GetMapping
  Map<String, List<Map<String, Object>>> calendar(@CurrentUser long userId,
      @RequestParam MultiValueMap<String, String> params) {
    QueryParams q = new QueryParams(params);
    LocalDate from = q.requiredDate("from");
    LocalDate to = q.requiredDate("to");
    ZoneId zone = q.zone("tz");
    if (from != null && to != null) {
      if (to.isBefore(from)) {
        q.validator().error("to", "to must not be before from");
      } else if (TimeUtil.daysBetween(from, to) >= MAX_RANGE_DAYS) {
        q.validator().error("to", "Range must be at most " + MAX_RANGE_DAYS + " days");
      }
    }
    q.finish();

    // Local days start up to ~14h before/after UTC days: over-fetch a day each side, filter by local date.
    Instant lo = from.minusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
    Instant hi = to.plusDays(2).atStartOfDay(ZoneOffset.UTC).toInstant();

    List<Map<String, Object>> events = new ArrayList<>();
    for (ApplicationRow a : applications.appliedBetween(userId, from, to)) {
      events.add(event(a.appliedDate(), "applied", a.id(), a.companyName(), a.jobTitle(), null));
    }
    for (HistoryRepository.WithApplication h : history.changesBetween(userId, lo, hi)) {
      LocalDate date = TimeUtil.dateInZone(h.history().changedAt(), zone);
      if (inRange(date, from, to)) {
        Map<String, Object> e = event(date, "statusChange", h.history().applicationId(), h.companyName(),
            h.jobTitle(), h.history().changedAt());
        e.put("status", h.history().toStatus());
        events.add(e);
      }
    }
    for (InterviewRow i : interviews.between(userId, lo, hi)) {
      LocalDate date = TimeUtil.dateInZone(i.scheduledAt(), zone);
      if (inRange(date, from, to)) {
        Map<String, Object> e = event(date, "interview", i.applicationId(), i.companyName(), i.title(),
            i.scheduledAt());
        e.put("interviewId", i.id());
        e.put("interviewType", i.type());
        events.add(e);
      }
    }
    for (ApplicationRow a : applications.followUpsBetween(userId, lo, hi)) {
      LocalDate date = TimeUtil.dateInZone(a.followUpAt(), zone);
      if (inRange(date, from, to)) {
        events.add(event(date, "followUp", a.id(), a.companyName(), a.jobTitle(), a.followUpAt()));
      }
    }

    events.sort(Comparator
        .comparing((Map<String, Object> e) -> (String) e.get("date"))
        .thenComparing(e -> e.get("at") == null ? "" : (String) e.get("at"))
        .thenComparingLong(e -> (Long) e.get("applicationId")));
    return Map.of("events", events);
  }

  private static boolean inRange(LocalDate date, LocalDate from, LocalDate to) {
    return !date.isBefore(from) && !date.isAfter(to);
  }

  private static Map<String, Object> event(LocalDate date, String type, long applicationId, String companyName,
      String title, Instant at) {
    Map<String, Object> e = new LinkedHashMap<>();
    e.put("date", date.toString());
    e.put("type", type);
    e.put("applicationId", applicationId);
    e.put("companyName", companyName);
    e.put("title", title);
    if (at != null) {
      e.put("at", Iso.format(at));
    }
    return e;
  }
}
