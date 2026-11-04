package com.jobtrail.tracker.dashboard;

import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.time.TimeUtil;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.tracker.applications.ApplicationRepository;
import com.jobtrail.tracker.history.HistoryRepository;
import com.jobtrail.tracker.interviews.InterviewDto;
import com.jobtrail.tracker.interviews.InterviewRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/dashboard")
public class DashboardController {

  private static final int WEEKS = 8;

  public record Week(LocalDate weekStart, long count) {}

  public record Activity(long applicationId, String companyName, ApplicationStatus toStatus, Instant changedAt) {}

  public record Dashboard(
      long total,
      long active,
      long responseRatePercent,
      Map<String, Long> statusCounts,
      List<Week> weekly,
      List<InterviewDto> upcomingInterviews,
      List<Activity> recentActivity) {}

  private final ApplicationRepository applications;
  private final InterviewRepository interviews;
  private final HistoryRepository history;

  public DashboardController(ApplicationRepository applications, InterviewRepository interviews,
      HistoryRepository history) {
    this.applications = applications;
    this.interviews = interviews;
    this.history = history;
  }

  @GetMapping
  Dashboard dashboard(@CurrentUser long userId, @RequestParam MultiValueMap<String, String> params) {
    QueryParams q = new QueryParams(params);
    ZoneId zone = q.zone("tz");
    q.finish();

    Instant now = Instant.now();
    // Weeks start on Monday in the user's zone; the oldest of the 8 buckets is 7 weeks back.
    LocalDate currentWeek = TimeUtil.mondayOf(TimeUtil.dateInZone(now, zone));
    LocalDate firstWeek = currentWeek.minusWeeks(WEEKS - 1L);

    Map<ApplicationStatus, Long> grouped = applications.countByStatus(userId);
    Map<String, Long> statusCounts = new LinkedHashMap<>();
    for (ApplicationStatus s : ApplicationStatus.values()) {
      statusCounts.put(s.name(), grouped.getOrDefault(s, 0L));
    }
    long total = statusCounts.values().stream().mapToLong(Long::longValue).sum();
    long active = total - statusCounts.get("offer") - statusCounts.get("rejected");
    long responded = total - statusCounts.get("applied");

    Map<LocalDate, Long> byWeek = applications.countByWeek(userId, firstWeek);
    List<Week> weekly = IntStream.range(0, WEEKS)
        .mapToObj(i -> firstWeek.plusWeeks(i))
        .map(start -> new Week(start, byWeek.getOrDefault(start, 0L)))
        .toList();

    List<InterviewDto> upcoming = interviews.upcomingPending(userId, now, 3).stream().map(InterviewDto::from).toList();
    List<Activity> recent = history.recentChanges(userId, 5).stream()
        .map(h -> new Activity(h.history().applicationId(), h.companyName(), h.history().toStatus(),
            h.history().changedAt()))
        .toList();

    return new Dashboard(total, active, total == 0 ? 0 : Math.round(100.0 * responded / total), statusCounts,
        weekly, upcoming, recent);
  }
}
