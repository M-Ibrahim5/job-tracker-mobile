package com.jobtrail.tracker.applications;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.EmploymentType;
import com.jobtrail.common.model.JobSource;
import com.jobtrail.common.model.WorkArrangement;
import com.jobtrail.common.validation.JsonBody;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Parses and validates application request bodies (docs/API.md "Validation"). The result only
 * contains keys the client sent, so PATCH can tell "omitted" from "set to null"; {@code status} is
 * read on create only (PATCH ignores it).
 */
public final class ApplicationInput {

  private ApplicationInput() {}

  public static Map<String, Object> parse(JsonNode json, boolean create) {
    JsonBody b = JsonBody.of(json);
    Map<String, Object> v = new LinkedHashMap<>();

    if (create || b.has("jobTitle")) {
      v.put("jobTitle", b.requiredText("jobTitle", 100));
    }
    if (create || b.has("companyName")) {
      v.put("companyName", b.requiredText("companyName", 100));
    }
    if (create || b.has("location")) {
      v.put("location", b.requiredText("location", 100));
    }
    if (create || b.has("workArrangement")) {
      v.put("workArrangement", b.requiredEnum("workArrangement", WorkArrangement.class));
    }
    if (create || b.has("appliedDate")) {
      LocalDate date = b.requiredDate("appliedDate");
      if (date != null && date.isAfter(LocalDate.now(ZoneOffset.UTC).plusDays(1))) {
        b.validator().error("appliedDate", "Date cannot be in the future");
        date = null;
      }
      v.put("appliedDate", date);
    }

    if (b.has("jobDescription")) {
      v.put("jobDescription", b.optionalText("jobDescription", 10_000));
    }
    if (b.has("applicationLink")) {
      v.put("applicationLink", b.optionalHttpUrl("applicationLink"));
    }
    if (b.has("employmentType")) {
      v.put("employmentType", b.optionalEnum("employmentType", EmploymentType.class));
    }
    if (b.has("salaryRange")) {
      v.put("salaryRange", b.optionalText("salaryRange", 100));
    }
    if (b.has("source")) {
      v.put("source", b.optionalEnum("source", JobSource.class));
    }
    if (b.has("notes")) {
      v.put("notes", b.optionalText("notes", 10_000));
    }
    if (b.has("contactName")) {
      v.put("contactName", b.optionalText("contactName", 100));
    }
    if (b.has("contactEmail")) {
      v.put("contactEmail", b.optionalEmail("contactEmail"));
    }
    if (b.has("followUpAt")) {
      v.put("followUpAt", b.optionalInstant("followUpAt"));
    }
    if (create) {
      ApplicationStatus status = b.optionalEnum("status", ApplicationStatus.class);
      v.put("status", status == null ? ApplicationStatus.applied : status);
    }
    b.finish();
    return v;
  }

  public record StatusChange(ApplicationStatus status, String note) {}

  public static StatusChange parseStatusChange(JsonNode json) {
    JsonBody b = JsonBody.of(json);
    ApplicationStatus status = b.requiredEnum("status", ApplicationStatus.class);
    String note = b.optionalText("note", 500);
    b.finish();
    return new StatusChange(status, note);
  }
}
