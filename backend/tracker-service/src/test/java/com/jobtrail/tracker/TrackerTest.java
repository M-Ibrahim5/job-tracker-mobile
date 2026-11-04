package com.jobtrail.tracker;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.jobtrail.common.security.JwtService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(DbSettingsClientConfig.class)
abstract class TrackerTest {

  @Autowired protected MockMvc mvc;
  @Autowired protected JdbcTemplate jdbc;
  @Autowired protected ObjectMapper json;
  @Autowired protected JwtService jwt;

  @BeforeEach
  void cleanDatabase() {
    // Foreign keys cascade to every dependent table.
    jdbc.update("DELETE FROM users");
  }

  /** The user service owns accounts; tests insert the rows it would have created. */
  protected long createUser(String email) {
    jdbc.update("INSERT INTO users (email, password_hash, full_name) VALUES (?, 'x', 'Test User')", email);
    Long id = jdbc.queryForObject("SELECT id FROM users WHERE email = ?", Long.class, email);
    jdbc.update("INSERT INTO user_settings (user_id, default_reminder_offsets, default_followup_days) "
        + "VALUES (?, '[1440, 60]', 7)", id);
    return id;
  }

  protected String token(long userId) {
    return jwt.sign(userId);
  }

  protected String newToken(String email) {
    return token(createUser(email));
  }

  // ----- HTTP helpers -------------------------------------------------------------------------

  protected ResultActions send(MockHttpServletRequestBuilder request, String token, Object body, String tz)
      throws Exception {
    if (token != null) {
      request.header("Authorization", "Bearer " + token);
    }
    if (tz != null) {
      request.header("X-Timezone", tz);
    }
    if (body != null) {
      request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
    }
    return mvc.perform(request);
  }

  protected ResultActions get(String path, String token) throws Exception {
    return send(MockMvcRequestBuilders.get(path), token, null, null);
  }

  protected ResultActions get(String path, String token, String tz) throws Exception {
    return send(MockMvcRequestBuilders.get(path), token, null, tz);
  }

  protected ResultActions post(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.post(path), token, body, null);
  }

  protected ResultActions post(String path, String token, Object body, String tz) throws Exception {
    return send(MockMvcRequestBuilders.post(path), token, body, tz);
  }

  protected ResultActions patch(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.patch(path), token, body, null);
  }

  protected ResultActions delete(String path, String token) throws Exception {
    return send(MockMvcRequestBuilders.delete(path), token, null, null);
  }

  protected ResultActions delete(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.delete(path), token, body, null);
  }

  protected JsonNode body(ResultActions result) throws Exception {
    return json.readTree(result.andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
  }

  // ----- fixtures -----------------------------------------------------------------------------

  protected static LocalDate today() {
    return LocalDate.now(ZoneOffset.UTC);
  }

  protected static String daysFromToday(int n) {
    return today().plusDays(n).toString();
  }

  protected static String inDays(int days) {
    return com.jobtrail.common.time.Iso.format(Instant.now().plus(days, ChronoUnit.DAYS));
  }

  /** Creates an application through the API and returns its JSON. */
  protected JsonNode createApplication(String token, Map<String, Object> overrides) throws Exception {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("jobTitle", "Flutter Developer");
    body.put("companyName", "Northwind Labs");
    body.put("location", "Kuala Lumpur");
    body.put("workArrangement", "hybrid");
    body.put("appliedDate", daysFromToday(0));
    body.putAll(overrides);
    ResultActions result = post("/api/v1/applications", token, body);
    JsonNode created = body(result);
    if (result.andReturn().getResponse().getStatus() != 201) {
      throw new AssertionError("createApplication failed: " + created);
    }
    return created;
  }

  protected JsonNode createApplication(String token) throws Exception {
    return createApplication(token, Map.of());
  }

  protected ResultActions createInterview(String token, long applicationId, Map<String, Object> overrides)
      throws Exception {
    return createInterview(token, applicationId, overrides, null);
  }

  protected ResultActions createInterview(String token, long applicationId, Map<String, Object> overrides, String tz)
      throws Exception {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("title", "Technical interview");
    body.put("type", "video");
    body.put("scheduledAt", inDays(3));
    body.putAll(overrides);
    return post("/api/v1/applications/" + applicationId + "/interviews", token, body, tz);
  }

  protected int count(String sql, Object... args) {
    Integer n = jdbc.queryForObject(sql, Integer.class, args);
    return n == null ? 0 : n;
  }
}
