package com.jobtrail.tracker.applications;

import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.EmploymentType;
import com.jobtrail.common.model.JobSource;
import com.jobtrail.common.model.WorkArrangement;
import java.time.Instant;
import java.time.LocalDate;

public record ApplicationRow(
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
    Instant updatedAt) {}
