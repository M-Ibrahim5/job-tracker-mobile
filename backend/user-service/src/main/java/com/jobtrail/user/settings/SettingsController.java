package com.jobtrail.user.settings;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.security.CurrentUser;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me/settings")
public class SettingsController {

  private final SettingsService settings;

  public SettingsController(SettingsService settings) {
    this.settings = settings;
  }

  @GetMapping
  SettingsDto get(@CurrentUser long userId) {
    return settings.get(userId);
  }

  @PatchMapping
  SettingsDto patch(@CurrentUser long userId, @RequestBody JsonNode body) {
    return settings.update(userId, body);
  }
}
