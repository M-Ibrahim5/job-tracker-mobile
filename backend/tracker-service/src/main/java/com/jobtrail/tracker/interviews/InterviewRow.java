package com.jobtrail.tracker.interviews;

import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.InterviewType;
import java.time.Instant;
import java.util.List;

/** An interview joined with its application's title and company. */
public record InterviewRow(
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
    List<Integer> reminderOffsets,
    InterviewOutcome outcome,
    Instant createdAt,
    Instant updatedAt) {}
