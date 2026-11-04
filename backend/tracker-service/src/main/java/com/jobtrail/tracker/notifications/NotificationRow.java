package com.jobtrail.tracker.notifications;

import com.jobtrail.common.model.NotificationType;
import java.time.Instant;

public record NotificationRow(
    long id,
    NotificationType type,
    String title,
    String body,
    Long relatedApplicationId,
    Long relatedInterviewId,
    Instant visibleAt,
    boolean read) {}
