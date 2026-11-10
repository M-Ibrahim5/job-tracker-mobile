package com.jobtrail.tracker.interviews;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.InterviewType;
import com.jobtrail.common.validation.JsonBody;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/**
 * Validated interview request body. {@code values} only holds keys that were sent (so PATCH can
 * tell "omitted" from "set to null"); {@code reminderOffsets} is deduplicated, null when omitted.
 */
public record InterviewInput(Map<String, Object> values, List<Integer> reminderOffsets) {

  private static final String TOO_MANY = "At most 5 reminders";
  /** Shortest and longest "minutes before the interview" a reminder may use (5 min to 30 days). */
  public static final int MIN_REMINDER_OFFSET_MINUTES = 5;
  public static final int MAX_REMINDER_OFFSET_MINUTES = 43200;

  public static InterviewInput parse(JsonNode json, boolean create) {
    JsonBody b = JsonBody.of(json);
    Map<String, Object> v = new LinkedHashMap<>();

    if (create || b.has("title")) {
      v.put("title", b.requiredText("title", 150));
    }
    if (create || b.has("type")) {
      v.put("type", b.requiredEnum("type", InterviewType.class));
    }
    if (create || b.has("scheduledAt")) {
      v.put("scheduledAt", b.requiredInstant("scheduledAt"));
    }
    if (create) {
      v.put("durationMinutes", b.has("durationMinutes") ? b.optionalInt("durationMinutes", 1, 1440) : null);
      if (v.get("durationMinutes") == null) {
        v.put("durationMinutes", 60);
      }
    } else if (b.has("durationMinutes")) {
      v.put("durationMinutes", b.requiredInt("durationMinutes", 1, 1440));
    }
    optional(b, v, "locationOrLink", 2048);
    optional(b, v, "interviewerName", 100);
    optional(b, v, "notes", 10_000);
    if (create) {
      InterviewOutcome outcome = b.optionalEnum("outcome", InterviewOutcome.class);
      v.put("outcome", outcome == null ? InterviewOutcome.pending : outcome);
    } else if (b.has("outcome")) {
      v.put("outcome", b.requiredEnum("outcome", InterviewOutcome.class));
    }

    List<Integer> offsets = null;
    if (create && b.has("reminderOffsetsMinutes")) {
      offsets = b.optionalIntList("reminderOffsetsMinutes", MIN_REMINDER_OFFSET_MINUTES, MAX_REMINDER_OFFSET_MINUTES, TOO_MANY);
    } else if (!create && b.has("reminderOffsetsMinutes")) {
      offsets = b.requiredIntList("reminderOffsetsMinutes", MIN_REMINDER_OFFSET_MINUTES, MAX_REMINDER_OFFSET_MINUTES, TOO_MANY);
    }
    b.finish();
    return new InterviewInput(v, offsets == null ? null : List.copyOf(new LinkedHashSet<>(offsets)));
  }

  private static void optional(JsonBody b, Map<String, Object> v, String field, int max) {
    if (b.has(field)) {
      v.put(field, b.optionalText(field, max));
    }
  }
}
