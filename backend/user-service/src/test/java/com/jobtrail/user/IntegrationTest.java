package com.jobtrail.user;


import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
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
abstract class IntegrationTest {

  static final String PASSWORD = "Passw0rd!";

  @Autowired protected MockMvc mvc;
  @Autowired protected JdbcTemplate jdbc;
  @Autowired protected ObjectMapper json;

  @BeforeEach
  void cleanDatabase() {
    // Foreign keys cascade to every dependent table.
    jdbc.update("DELETE FROM users");
    // Not tied to a user row (unknown e-mails are throttled too).
    jdbc.update("DELETE FROM login_throttle");
  }

  protected ResultActions send(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
    if (token != null) {
      request.header("Authorization", "Bearer " + token);
    }
    if (body != null) {
      request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
    }
    return mvc.perform(request);
  }

  protected ResultActions post(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.post(path), token, body);
  }

  protected ResultActions patch(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.patch(path), token, body);
  }

  protected ResultActions get(String path, String token) throws Exception {
    return send(MockMvcRequestBuilders.get(path), token, null);
  }

  protected ResultActions delete(String path, String token, Object body) throws Exception {
    return send(MockMvcRequestBuilders.delete(path), token, body);
  }

  protected JsonNode body(ResultActions result) throws Exception {
    return json.readTree(result.andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
  }

  /** Registers a user through the API and returns the AuthResponse. */
  protected JsonNode register(String email) throws Exception {
    return body(post("/api/v1/auth/register", null,
        java.util.Map.of("fullName", "Test User", "email", email, "password", PASSWORD)));
  }
}
