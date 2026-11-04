package com.jobtrail.tracker.data;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.time.Iso;
import com.jobtrail.common.time.TimeUtil;
import com.jobtrail.common.validation.JsonBody;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.tracker.applications.ApplicationDto;
import com.jobtrail.tracker.applications.ApplicationRepository;
import com.jobtrail.tracker.applications.ApplicationRow;
import com.jobtrail.tracker.history.HistoryDto;
import com.jobtrail.tracker.history.HistoryRepository;
import com.jobtrail.tracker.history.HistoryRow;
import com.jobtrail.tracker.interviews.InterviewDto;
import com.jobtrail.tracker.interviews.InterviewRepository;
import com.jobtrail.tracker.interviews.InterviewRow;
import com.jobtrail.tracker.notifications.NotificationRepository;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Export (JSON or CSV, streamed in keyset pages) and delete-all. */
@RestController
public class DataController {

  private static final int BATCH = 500;
  private static final Pattern FORMULA = Pattern.compile("^[=+\\-@\\t\\r].*", Pattern.DOTALL);
  private static final Pattern NEEDS_QUOTES = Pattern.compile("[\",\\r\\n]");

  private static final List<String> CSV_COLUMNS = List.of(
      "id", "jobTitle", "companyName", "location", "workArrangement", "employmentType", "salaryRange", "source",
      "appliedDate", "status", "applicationLink", "contactName", "contactEmail", "followUpAt", "notes",
      "jobDescription", "createdAt", "updatedAt");

  /** CSV timestamps read like {@code 01/11/2026 | 02:35 AM}. */
  private static final DateTimeFormatter CSV_STAMP =
      DateTimeFormatter.ofPattern("dd/MM/yyyy | hh:mm a", Locale.ENGLISH);
  private static final List<String> CSV_TIMESTAMP_COLUMNS = List.of("createdAt", "updatedAt");

  private final ApplicationRepository applications;
  private final HistoryRepository history;
  private final InterviewRepository interviews;
  private final NotificationRepository notifications;
  private final TransactionTemplate tx;
  private final ObjectMapper mapper;

  public DataController(ApplicationRepository applications, HistoryRepository history,
      InterviewRepository interviews, NotificationRepository notifications, TransactionTemplate tx,
      ObjectMapper mapper) {
    this.applications = applications;
    this.history = history;
    this.interviews = interviews;
    this.notifications = notifications;
    this.tx = tx;
    this.mapper = mapper;
  }

  /** RFC 4180 escaping, plus a leading quote to neutralise spreadsheet formula injection. */
  static String csvCell(Object value) {
    if (value == null) {
      return "";
    }
    String s = value.toString();
    if (FORMULA.matcher(s).matches()) {
      s = "'" + s;
    }
    return NEEDS_QUOTES.matcher(s).find() ? "\"" + s.replace("\"", "\"\"") + "\"" : s;
  }

  @GetMapping("/api/v1/export")
  void export(@CurrentUser long userId, @RequestParam MultiValueMap<String, String> params,
      @RequestHeader(value = "X-Timezone", required = false) String tz,
      HttpServletResponse response) throws IOException {
    QueryParams q = new QueryParams(params);
    String format = q.lower("format", "json");
    if (!format.equals("json") && !format.equals("csv")) {
      q.validator().error("format", "Must be json or csv");
    }
    q.finish();

    Instant now = Instant.now();
    response.setHeader("Content-Disposition",
        "attachment; filename=\"jobtrail-export-" + Iso.format(now).substring(0, 10) + "." + format + "\"");
    response.setContentType(format.equals("csv") ? "text/csv; charset=utf-8" : "application/json; charset=utf-8");
    try (Writer out = new BufferedWriter(new OutputStreamWriter(response.getOutputStream(), StandardCharsets.UTF_8))) {
      if (format.equals("csv")) {
        writeCsv(userId, now, TimeUtil.zoneOrUtc(tz), out);
      } else {
        writeJson(userId, now, out);
      }
    }
  }

  private void writeCsv(long userId, Instant now, ZoneId zone, Writer out) throws IOException {
    out.write(String.join(",", CSV_COLUMNS) + "\r\n");
    long cursor = 0;
    for (;;) {
      List<ApplicationRow> rows = applications.pageAfter(userId, cursor, BATCH, now);
      for (ApplicationRow row : rows) {
        JsonNode dto = mapper.valueToTree(ApplicationDto.from(row));
        StringBuilder line = new StringBuilder();
        for (int i = 0; i < CSV_COLUMNS.size(); i++) {
          if (i > 0) {
            line.append(',');
          }
          String column = CSV_COLUMNS.get(i);
          JsonNode cell = dto.get(column);
          String text = cell == null || cell.isNull() ? null : cell.asText();
          if (text != null && CSV_TIMESTAMP_COLUMNS.contains(column)) {
            text = CSV_STAMP.format(Instant.parse(text).atZone(zone));
          }
          line.append(csvCell(text));
        }
        out.write(line.append("\r\n").toString());
      }
      if (rows.size() < BATCH) {
        return;
      }
      cursor = rows.get(rows.size() - 1).id();
    }
  }

  private void writeJson(long userId, Instant now, Writer out) throws IOException {
    out.write("{\"exportedAt\":" + mapper.writeValueAsString(Iso.format(now)) + ",\"applications\":[");
    boolean first = true;
    long cursor = 0;
    for (;;) {
      List<ApplicationRow> rows = applications.pageAfter(userId, cursor, BATCH, now);
      List<Long> ids = rows.stream().map(ApplicationRow::id).toList();
      Map<Long, List<HistoryRow>> histories = history.forApplications(userId, ids);
      Map<Long, List<InterviewRow>> interviewsByApp = interviews.forApplications(userId, ids);
      for (ApplicationRow row : rows) {
        ObjectNode item = mapper.valueToTree(ApplicationDto.from(row));
        item.remove("nextInterviewAt");
        item.set("history", mapper.valueToTree(
            histories.getOrDefault(row.id(), List.of()).stream().map(HistoryDto::from).toList()));
        item.set("interviews", mapper.valueToTree(
            interviewsByApp.getOrDefault(row.id(), List.of()).stream().map(InterviewDto::from).toList()));
        out.write((first ? "" : ",") + mapper.writeValueAsString(item));
        first = false;
      }
      if (rows.size() < BATCH) {
        break;
      }
      cursor = rows.get(rows.size() - 1).id();
    }
    out.write("]}");
  }

  @DeleteMapping("/api/v1/data")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void deleteAll(@CurrentUser long userId, @RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    body.requireLiteral("confirm", "DELETE", "Type DELETE to confirm");
    body.finish();
    // Applications cascade to history, interviews and their notifications; sweep the rest too.
    tx.executeWithoutResult(s -> {
      applications.deleteAll(userId);
      notifications.deleteAll(userId);
    });
  }
}
