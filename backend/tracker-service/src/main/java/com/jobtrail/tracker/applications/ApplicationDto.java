package com.jobtrail.tracker.applications;

import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.EmploymentType;
import com.jobtrail.common.model.JobSource;
import com.jobtrail.common.model.WorkArrangement;
import java.time.Instant;
import java.time.LocalDate;

/** The {@code JobApplication} object of docs/API.md. */
public record ApplicationDto(
    long id,
    String jobTitle,
    String companyName,
    String location,
    WorkArrangement workArrangement,
    String jobDescription,
    String applicationLink,
    EmploymentType employmentType,
    String salaryRange,
    JobSource source,
    LocalDate appliedDate,
    ApplicationStatus status,
    String notes,
    String contactName,
    String contactEmail,
    Instant followUpAt,
    Instant nextInterviewAt,
    Instant createdAt,
    Instant updatedAt) {

  public static ApplicationDto from(ApplicationRow r) {
    return new ApplicationDto(r.id(), r.jobTitle(), r.companyName(), r.location(), r.workArrangement(),
        r.jobDescription(), r.applicationLink(), r.employmentType(), r.salaryRange(), r.source(), r.appliedDate(),
        r.status(), r.notes(), r.contactName(), r.contactEmail(), r.followUpAt(), r.nextInterviewAt(),
        r.createdAt(), r.updatedAt());
  }
}
