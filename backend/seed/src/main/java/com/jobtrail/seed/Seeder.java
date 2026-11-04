package com.jobtrail.seed;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.json.IntList;
import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.reminder.ReminderText;
import com.jobtrail.seed.DemoData.App;
import com.jobtrail.seed.DemoData.Interview;
import com.jobtrail.seed.DemoData.Step;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** Creates {@code demo@jobtrail.test / Demo@1234} and (re)loads its demo data. */
@Component
class Seeder implements CommandLineRunner {

  private static final Logger log = LoggerFactory.getLogger(Seeder.class);

  static final String EMAIL = "demo@jobtrail.test";
  static final String PASSWORD = "Demo@1234";
  private static final ZoneId REMINDER_ZONE = ZoneId.of("Asia/Kuala_Lumpur");
  private static final List<Integer> OFFSETS = List.of(1440, 60);

  private final JdbcClient jdbc;
  private final TransactionTemplate tx;

  Seeder(JdbcClient jdbc, TransactionTemplate tx) {
    this.jdbc = jdbc;
    this.tx = tx;
  }

  @Override
  public void run(String... args) {
    // Same parameters as the user service (argon2id, 64 MiB, 3 passes, 4 lanes).
    String hash = new Argon2PasswordEncoder(16, 32, 1, 19456, 2).encode(PASSWORD);
    List<App> apps = DemoData.apps();
    tx.executeWithoutResult(status -> {
      long userId = upsertUser(hash);
      seedApplications(userId, apps);
    });
    log.info("Seeded demo user {} with {} applications", EMAIL, apps.size());
  }

  private long upsertUser(String hash) {
    List<Long> existing = jdbc.sql("SELECT id FROM users WHERE email = :email")
        .param("email", EMAIL).query(Long.class).list();
    if (!existing.isEmpty()) {
      jdbc.sql("UPDATE users SET password_hash = :hash WHERE id = :id")
          .param("hash", hash).param("id", existing.get(0)).update();
      return existing.get(0);
    }
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO users (email, password_hash, full_name, job_role, location, email_verified_at)
            VALUES (:email, :hash, 'Demo User', 'Software Engineer', 'Kuala Lumpur, Malaysia', :verified)""")
        .param("email", EMAIL)
        .param("hash", hash)
        .param("verified", Db.ts(Instant.now()))
        .update(keys);
    long id = keys.getKey().longValue();
    jdbc.sql("""
            INSERT INTO user_settings (user_id, default_reminder_offsets, default_followup_days)
            VALUES (:user, CAST(:offsets AS JSON), 7)""")
        .param("user", id)
        .param("offsets", IntList.toJson(OFFSETS))
        .update();
    return id;
  }

  private void seedApplications(long userId, List<App> apps) {
    // Re-seeding replaces the demo data (cascades history, interviews and notifications).
    jdbc.sql("DELETE FROM job_applications WHERE user_id = :user").param("user", userId).update();
    jdbc.sql("DELETE FROM notifications WHERE user_id = :user").param("user", userId).update();
    Instant now = Instant.now();
    for (App app : apps) {
      seedApplication(userId, app, now);
    }
  }

  private void seedApplication(long userId, App app, Instant now) {
    Instant applied = DemoData.daysAgo(app.appliedDaysAgo, 3);
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO job_applications
              (user_id, job_title, company_name, location, work_arrangement, employment_type, source,
               salary_range, applied_date, status, notes, contact_name, contact_email, follow_up_at, created_at)
            VALUES
              (:user, :title, :company, :location, :arrangement, :employment, :source,
               :salary, :appliedDate, :status, :notes, :contactName, :contactEmail, :followUp, :created)""")
        .param("user", userId)
        .param("title", app.jobTitle)
        .param("company", app.companyName)
        .param("location", app.location)
        .param("arrangement", app.arrangement.name())
        .param("employment", app.employmentType.name())
        .param("source", app.source.name())
        .param("salary", app.salaryRange)
        .param("appliedDate", DemoData.dateOnly(app.appliedDaysAgo))
        .param("status", app.finalStatus().name())
        .param("notes", app.notes)
        .param("contactName", app.contactName)
        .param("contactEmail", app.contactEmail)
        .param("followUp", Db.ts(app.followUpAt))
        .param("created", Db.ts(applied))
        .update(keys);
    long appId = keys.getKey().longValue();

    insertHistory(userId, appId, null, ApplicationStatus.applied, applied, null);
    ApplicationStatus from = ApplicationStatus.applied;
    for (Step step : app.path) {
      Instant changedAt = applied.plus(step.dayOffset(), ChronoUnit.DAYS);
      insertHistory(userId, appId, from, step.to(), changedAt, step.note());
      if (!changedAt.isAfter(now)) {
        insertNotification(userId, "statusChange", ReminderText.statusChangeTitle(step.to().label()),
            ReminderText.statusChangeBody(app.companyName, app.jobTitle), appId, null, changedAt,
            Duration.between(changedAt, now).compareTo(Duration.ofDays(4)) > 0);
      }
      from = step.to();
    }

    if (app.followUpAt != null) {
      insertNotification(userId, "followUpReminder", ReminderText.followUpTitle(app.companyName), app.jobTitle,
          appId, null, app.followUpAt, false);
    }

    for (Interview interview : app.interviews) {
      long interviewId = insertInterview(userId, appId, interview);
      for (int offset : OFFSETS) {
        insertNotification(userId, "interviewReminder", ReminderText.interviewTitle(offset),
            ReminderText.interviewBody(app.companyName, interview.scheduledAt(), interview.type(), REMINDER_ZONE),
            appId, interviewId, interview.scheduledAt().minus(offset, ChronoUnit.MINUTES),
            interview.scheduledAt().isBefore(now));
      }
    }
  }

  private void insertHistory(long userId, long appId, ApplicationStatus from, ApplicationStatus to, Instant at,
      String note) {
    jdbc.sql("""
            INSERT INTO status_history (user_id, application_id, from_status, to_status, changed_at, note)
            VALUES (:user, :app, :from, :to, :at, :note)""")
        .param("user", userId)
        .param("app", appId)
        .param("from", from == null ? null : from.name())
        .param("to", to.name())
        .param("at", Db.ts(at))
        .param("note", note)
        .update();
  }

  private long insertInterview(long userId, long appId, Interview i) {
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO interviews
              (user_id, application_id, title, type, scheduled_at, location_or_link, interviewer_name,
               reminder_offsets, outcome)
            VALUES
              (:user, :app, :title, :type, :at, :link, :interviewer, CAST(:offsets AS JSON), :outcome)""")
        .param("user", userId)
        .param("app", appId)
        .param("title", i.title())
        .param("type", i.type().name())
        .param("at", Db.ts(i.scheduledAt()))
        .param("link", i.link())
        .param("interviewer", i.interviewer())
        .param("offsets", IntList.toJson(OFFSETS))
        .param("outcome", (i.outcome() == null ? InterviewOutcome.pending : i.outcome()).name())
        .update(keys);
    return keys.getKey().longValue();
  }

  private void insertNotification(long userId, String type, String title, String body, Long appId,
      Long interviewId, Instant visibleAt, boolean read) {
    jdbc.sql("""
            INSERT INTO notifications
              (user_id, type, title, body, related_application_id, related_interview_id, visible_at, is_read)
            VALUES (:user, :type, :title, :body, :app, :interview, :visible, :read)""")
        .param("user", userId)
        .param("type", type)
        .param("title", title)
        .param("body", body)
        .param("app", appId)
        .param("interview", interviewId)
        .param("visible", Db.ts(visibleAt))
        .param("read", read)
        .update();
  }
}
