package com.jobtrail.tracker.notifications;

import com.jobtrail.common.model.NotificationType;
import java.time.Instant;

/** A notification to insert; reminders use their fire time as {@code visibleAt}. */
public record NewNotification(
    long userId,
    NotificationType type,
    String title,
    String body,
    Long relatedApplicationId,
    Long relatedInterviewId,
    Instant visibleAt) {}
