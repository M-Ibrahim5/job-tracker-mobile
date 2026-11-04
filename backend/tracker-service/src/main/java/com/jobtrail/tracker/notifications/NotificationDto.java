package com.jobtrail.tracker.notifications;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.jobtrail.common.model.NotificationType;
import java.time.Instant;

/** The {@code Notification} object of docs/API.md; {@code createdAt} is the row's {@code visible_at}. */
public record NotificationDto(
    long id,
    NotificationType type,
    String title,
    String body,
    Long relatedApplicationId,
    Long relatedInterviewId,
    Instant createdAt,
    @JsonProperty("isRead") boolean isRead) {

  public static NotificationDto from(NotificationRow row) {
    return new NotificationDto(row.id(), row.type(), row.title(), row.body(), row.relatedApplicationId(),
        row.relatedInterviewId(), row.visibleAt(), row.read());
  }
}
