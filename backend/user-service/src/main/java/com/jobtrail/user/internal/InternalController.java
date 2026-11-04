package com.jobtrail.user.internal;

import com.jobtrail.common.error.AppException;
import com.jobtrail.user.settings.SettingsDto;
import com.jobtrail.user.settings.SettingsService;
import com.jobtrail.user.user.UserRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Service-to-service API (guarded by the internal key, never routed through the gateway).
 * The tracker service reads reminder preferences from here instead of touching user tables.
 */
@RestController
@RequestMapping("/internal/users")
public class InternalController {

  private final UserRepository users;
  private final SettingsService settings;

  public InternalController(UserRepository users, SettingsService settings) {
    this.users = users;
    this.settings = settings;
  }

  @GetMapping("/{id}/settings")
  SettingsDto settings(@PathVariable long id) {
    if (users.findById(id).isEmpty()) {
      throw AppException.notFound("User not found");
    }
    return settings.get(id);
  }
}
