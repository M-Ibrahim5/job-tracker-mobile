package com.jobtrail.tracker.settings;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.jobtrail.common.security.InternalKeyInterceptor;
import com.jobtrail.common.security.InternalProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** Calls {@code GET /internal/users/{id}/settings} on the user service with the shared key. */
@Component
public class HttpUserSettingsClient implements UserSettingsClient {

  private static final Logger log = LoggerFactory.getLogger(HttpUserSettingsClient.class);

  @JsonIgnoreProperties(ignoreUnknown = true)
  record Response(
      boolean interviewRemindersEnabled,
      boolean followUpRemindersEnabled,
      boolean statusAlertsEnabled,
      List<Integer> defaultReminderOffsetsMinutes,
      Integer defaultFollowUpDays) {}

  private final RestClient http;

  public HttpUserSettingsClient(
      @Value("${jobtrail.services.user-url:http://localhost:3001}") String userServiceUrl,
      InternalProperties internal) {
    HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
    JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(client);
    factory.setReadTimeout(Duration.ofSeconds(3));
    this.http = RestClient.builder()
        .baseUrl(userServiceUrl)
        .requestFactory(factory)
        .defaultHeader(InternalKeyInterceptor.HEADER, internal.key())
        .build();
  }

  @Override
  public ReminderPrefs prefsFor(long userId) {
    try {
      Response r = http.get().uri("/internal/users/{id}/settings", userId).retrieve().body(Response.class);
      if (r == null) {
        return ReminderPrefs.DEFAULTS;
      }
      return new ReminderPrefs(r.interviewRemindersEnabled(), r.followUpRemindersEnabled(),
          r.statusAlertsEnabled(), r.defaultReminderOffsetsMinutes(), r.defaultFollowUpDays());
    } catch (RestClientException e) {
      log.warn("Could not load settings for user {} from the user service, using defaults: {}", userId,
          e.getMessage());
      return ReminderPrefs.DEFAULTS;
    }
  }
}
