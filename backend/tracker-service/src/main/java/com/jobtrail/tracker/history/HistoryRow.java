package com.jobtrail.tracker.history;

import com.jobtrail.common.model.ApplicationStatus;
import java.time.Instant;

public record HistoryRow(
    long id,
    long applicationId,
    ApplicationStatus fromStatus,
    ApplicationStatus toStatus,
    Instant changedAt,
    String note) {}
