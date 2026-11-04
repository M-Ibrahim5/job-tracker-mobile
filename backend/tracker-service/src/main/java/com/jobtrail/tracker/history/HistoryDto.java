package com.jobtrail.tracker.history;

import com.jobtrail.common.model.ApplicationStatus;
import java.time.Instant;

/** The {@code StatusHistoryEntry} object of docs/API.md; {@code fromStatus} is null for the first entry. */
public record HistoryDto(
    long id,
    long applicationId,
    ApplicationStatus fromStatus,
    ApplicationStatus toStatus,
    Instant changedAt,
    String note) {

  public static HistoryDto from(HistoryRow row) {
    return new HistoryDto(row.id(), row.applicationId(), row.fromStatus(), row.toStatus(), row.changedAt(), row.note());
  }
}
