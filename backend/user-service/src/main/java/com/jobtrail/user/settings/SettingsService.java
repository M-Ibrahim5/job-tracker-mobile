package com.jobtrail.user.settings;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.db.UpdateBuilder;
import com.jobtrail.common.json.IntList;
import com.jobtrail.common.validation.JsonBody;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import org.springframework.stereotype.Service;

@Service
public class SettingsService {

  private final SettingsRepository settings;

  public SettingsService(SettingsRepository settings) {
    this.settings = settings;
  }

  public SettingsDto get(long userId) {
    settings.ensure(userId);
    return settings.find(userId);
  }

  /** Partial update: only the keys present in the body change. */
  public SettingsDto update(long userId, JsonNode json) {
    JsonBody body = JsonBody.of(json);
    UpdateBuilder update = UpdateBuilder.table("user_settings");
    if (body.has("theme")) {
      Theme theme = body.requiredEnum("theme", Theme.class);
      if (theme != null) {
        update.set("theme", theme);
      }
    }
    setBool(body, update, "interviewRemindersEnabled", "interview_reminders_enabled");
    setBool(body, update, "followUpRemindersEnabled", "followup_reminders_enabled");
    setBool(body, update, "statusAlertsEnabled", "status_alerts_enabled");
    if (body.has("defaultReminderOffsetsMinutes")) {
      var offsets = body.requiredIntList("defaultReminderOffsetsMinutes", 5, 43200, "At most 5 reminders");
      if (offsets != null) {
        update.setJson("default_reminder_offsets", IntList.toJson(new ArrayList<>(new LinkedHashSet<>(offsets))));
      }
    }
    if (body.has("defaultFollowUpDays")) {
      Integer days = body.optionalIntOneOf("defaultFollowUpDays", 3, 5, 7, 14);
      if (body.validator().valid()) {
        update.set("default_followup_days", days);
      }
    }
    body.finish();
    settings.ensure(userId);
    settings.update(userId, update);
    return settings.find(userId);
  }

  private static void setBool(JsonBody body, UpdateBuilder update, String field, String column) {
    if (body.has(field)) {
      Boolean value = body.requiredBool(field);
      if (value != null) {
        update.set(column, value);
      }
    }
  }
}
