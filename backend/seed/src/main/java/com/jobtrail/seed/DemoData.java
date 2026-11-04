package com.jobtrail.seed;

import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.EmploymentType;
import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.InterviewType;
import com.jobtrail.common.model.JobSource;
import com.jobtrail.common.model.WorkArrangement;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

/** The 15 demo applications (docs/DESIGN.md sample-data style), relative to "now". */
final class DemoData {

  /** A status change {@code dayOffset} days after applying. */
  record Step(ApplicationStatus to, int dayOffset, String note) {}

  record Interview(String title, InterviewType type, Instant scheduledAt, String interviewer,
      InterviewOutcome outcome, String link) {}

  static final class App {
    final String jobTitle;
    final String companyName;
    final String location;
    final WorkArrangement arrangement;
    final EmploymentType employmentType;
    final JobSource source;
    final int appliedDaysAgo;
    String salaryRange;
    Instant followUpAt;
    String contactName;
    String contactEmail;
    String notes;
    final List<Step> path = new ArrayList<>();
    final List<Interview> interviews = new ArrayList<>();

    App(String jobTitle, String companyName, String location, WorkArrangement arrangement,
        EmploymentType employmentType, JobSource source, int appliedDaysAgo) {
      this.jobTitle = jobTitle;
      this.companyName = companyName;
      this.location = location;
      this.arrangement = arrangement;
      this.employmentType = employmentType;
      this.source = source;
      this.appliedDaysAgo = appliedDaysAgo;
    }

    App salary(String value) {
      this.salaryRange = value;
      return this;
    }

    App followUp(Instant value) {
      this.followUpAt = value;
      return this;
    }

    App contact(String name, String email) {
      this.contactName = name;
      this.contactEmail = email;
      return this;
    }

    App notes(String value) {
      this.notes = value;
      return this;
    }

    App step(ApplicationStatus to, int dayOffset) {
      return step(to, dayOffset, null);
    }

    App step(ApplicationStatus to, int dayOffset, String note) {
      path.add(new Step(to, dayOffset, note));
      return this;
    }

    App interview(String title, InterviewType type, Instant at) {
      return interview(title, type, at, null, InterviewOutcome.pending, null);
    }

    App interview(String title, InterviewType type, Instant at, InterviewOutcome outcome) {
      return interview(title, type, at, null, outcome, null);
    }

    App interview(String title, InterviewType type, Instant at, String interviewer, InterviewOutcome outcome,
        String link) {
      interviews.add(new Interview(title, type, at, interviewer, outcome, link));
      return this;
    }

    ApplicationStatus finalStatus() {
      return path.isEmpty() ? ApplicationStatus.applied : path.get(path.size() - 1).to();
    }
  }

  private DemoData() {}

  /** {@code n} days ago at the given UTC hour (negative n = the future). */
  static Instant daysAgo(int n, int hourUtc) {
    return LocalDate.now(ZoneOffset.UTC).minusDays(n).atTime(hourUtc, 0).toInstant(ZoneOffset.UTC);
  }

  static LocalDate dateOnly(int n) {
    return LocalDate.now(ZoneOffset.UTC).minusDays(n);
  }

  /** {@code n} days from now at the given UTC hour (negative n = the past). */
  private static Instant at(int n, int hourUtc) {
    return daysAgo(-n, hourUtc);
  }

  static List<App> apps() {
    return List.of(
        new App("Senior Flutter Developer", "Northwind Labs", "Kuala Lumpur", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.linkedIn, 12)
            .salary("RM 9,000 – 12,000")
            .step(ApplicationStatus.screening, 3, "HR screening call booked")
            .step(ApplicationStatus.interview, 6, "Recruiter called")
            .contact("Aisha Rahman", "aisha@northwind.example")
            .notes("Team builds a logistics app. Ask about on-call.")
            .interview("HR screening", InterviewType.phone, at(-8, 2), InterviewOutcome.passed)
            .interview("Technical interview · Round 2", InterviewType.video, at(3, 2), "Daniel Lim",
                InterviewOutcome.pending, "https://meet.example.com/northwind-r2"),
        new App("Flutter Developer", "Orbit Health", "Petaling Jaya", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.jobStreet, 9)
            .followUp(at(1, 1))
            .contact("Priya Nair", "priya@orbithealth.example"),
        new App("Mobile Engineer", "Kite Payments", "Remote (APAC)", WorkArrangement.remote,
            EmploymentType.fullTime, JobSource.companySite, 20)
            .salary("USD 4,000 – 5,500")
            .step(ApplicationStatus.screening, 4)
            .step(ApplicationStatus.interview, 9)
            .step(ApplicationStatus.offer, 17, "Verbal offer received")
            .interview("Intro call", InterviewType.video, at(-14, 3), InterviewOutcome.passed)
            .interview("Take-home review", InterviewType.technical, at(-8, 6), InterviewOutcome.passed)
            .interview("Final round", InterviewType.finalRound, at(-3, 4), InterviewOutcome.passed),
        new App("Software Engineer II", "Harbor Logistics", "Singapore", WorkArrangement.onsite,
            EmploymentType.fullTime, JobSource.indeed, 30)
            .step(ApplicationStatus.screening, 5)
            .step(ApplicationStatus.rejected, 14, "Position filled internally"),
        new App("Frontend Developer", "Lumen Studio", "Kuala Lumpur", WorkArrangement.onsite,
            EmploymentType.contract, JobSource.referral, 5)
            .step(ApplicationStatus.screening, 2)
            .contact("Marcus Tan", "marcus@lumen.example"),
        new App("Android Developer", "Pinecone Apps", "Penang", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.linkedIn, 3),
        new App("Backend Engineer (Java)", "Tidal Commerce", "Kuala Lumpur", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.linkedIn, 16)
            .salary("RM 8,000 – 10,500")
            .step(ApplicationStatus.screening, 3)
            .step(ApplicationStatus.interview, 8)
            .interview("System design", InterviewType.technical, at(6, 7), "Wei Jie",
                InterviewOutcome.pending, null),
        new App("Junior Flutter Developer", "Greenleaf Tech", "Johor Bahru", WorkArrangement.onsite,
            EmploymentType.fullTime, JobSource.jobStreet, 24)
            .step(ApplicationStatus.rejected, 10, "Looking for more experience"),
        new App("Mobile Developer Intern", "Skyline Robotics", "Cyberjaya", WorkArrangement.onsite,
            EmploymentType.internship, JobSource.companySite, 40)
            .step(ApplicationStatus.screening, 6)
            .step(ApplicationStatus.interview, 15)
            .step(ApplicationStatus.rejected, 25)
            .interview("Phone interview", InterviewType.phone, at(-25, 3), InterviewOutcome.failed),
        new App("Cross-platform Developer", "Meridian Bank", "Kuala Lumpur", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.linkedIn, 7)
            .salary("RM 10,000 – 13,000")
            .step(ApplicationStatus.screening, 4)
            .followUp(at(4, 1)),
        new App("Flutter Engineer", "Cobalt Games", "Remote", WorkArrangement.remote,
            EmploymentType.contract, JobSource.other, 2),
        new App("Senior Mobile Engineer", "Atlas Travel", "Bangkok", WorkArrangement.remote,
            EmploymentType.fullTime, JobSource.referral, 28)
            .step(ApplicationStatus.screening, 4)
            .step(ApplicationStatus.interview, 12)
            .step(ApplicationStatus.offer, 26, "Offer letter received")
            .interview("Culture fit", InterviewType.hr, at(-16, 4), InterviewOutcome.passed)
            .interview("Pair programming", InterviewType.technical, at(-10, 5), InterviewOutcome.passed),
        new App("Application Developer", "Birchwood Insurance", "Kuala Lumpur", WorkArrangement.onsite,
            EmploymentType.fullTime, JobSource.indeed, 35)
            .step(ApplicationStatus.rejected, 20),
        new App("React Native Developer", "Quasar Media", "Selangor", WorkArrangement.hybrid,
            EmploymentType.partTime, JobSource.jobStreet, 1),
        new App("Software Engineer, Mobile", "Vertex Cloud", "Kuala Lumpur", WorkArrangement.hybrid,
            EmploymentType.fullTime, JobSource.companySite, 11)
            .step(ApplicationStatus.screening, 3)
            .step(ApplicationStatus.interview, 7)
            .interview("Onsite loop", InterviewType.onsite, at(10, 2), "Nur Aina",
                InterviewOutcome.pending, null));
  }
}
