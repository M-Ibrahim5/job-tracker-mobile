package com.jobtrail.common.reminder;

import com.jobtrail.common.model.InterviewType;
import com.jobtrail.common.time.TimeUtil;
import java.time.Instant;
import java.time.ZoneId;

/** Titles and bodies of reminder notifications; shared so the seed produces identical text. */
public final class ReminderText {

  private ReminderText() {}

  private static String unit(int n, String name) {
    return n + " " + name + (n == 1 ? "" : "s");
  }

  private static String offsetLabel(int minutes) {
    if (minutes % 1440 == 0) {
      return unit(minutes / 1440, "day");
    }
    if (minutes % 60 == 0) {
      return unit(minutes / 60, "hour");
    }
    return unit(minutes, "minute");
  }

  public static String interviewTitle(int offsetMinutes) {
    return "Interview in " + offsetLabel(offsetMinutes);
  }

  public static String interviewBody(
      String companyName, Instant scheduledAt, InterviewType type, ZoneId zone) {
    return companyName + " · " + TimeUtil.clock(scheduledAt, zone) + " · " + type.label();
  }

  public static String followUpTitle(String companyName) {
    return "Follow up with " + companyName;
  }

  public static String statusChangeTitle(String statusLabel) {
    return "Moved to " + statusLabel;
  }

  public static String statusChangeBody(String companyName, String jobTitle) {
    return companyName + " · " + jobTitle;
  }
}
