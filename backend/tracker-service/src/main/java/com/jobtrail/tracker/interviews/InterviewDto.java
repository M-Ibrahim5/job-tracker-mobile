package com.jobtrail.tracker.interviews;

import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.InterviewType;
import java.time.Instant;
import java.util.List;

/** The {@code Interview} object of docs/API.md. */
public record InterviewDto(
    long id,
    long applicationId,
    String applicationTitle,
    String companyName,
    String title,
    InterviewType type,
    Instant scheduledAt,
    int durationMinutes,
    String locationOrLink,
    String interviewerName,
    String notes,
    List<Integer> reminderOffsetsMinutes,
    InterviewOutcome outcome,
    Instant createdAt,
    Instant updatedAt) {

  public static InterviewDto from(InterviewRow r) {
    return new InterviewDto(r.id(), r.applicationId(), r.applicationTitle(), r.companyName(), r.title(), r.type(),
        r.scheduledAt(), r.durationMinutes(), r.locationOrLink(), r.interviewerName(), r.notes(),
        r.reminderOffsets(), r.outcome(), r.createdAt(), r.updatedAt());
  }
}
