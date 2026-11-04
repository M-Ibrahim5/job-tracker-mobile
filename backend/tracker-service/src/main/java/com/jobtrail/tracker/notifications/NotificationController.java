package com.jobtrail.tracker.notifications;

import com.jobtrail.common.error.AppException;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.validation.QueryParams;
import com.jobtrail.common.web.Ids;
import com.jobtrail.common.web.PageResponse;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

  private final NotificationRepository notifications;

  public NotificationController(NotificationRepository notifications) {
    this.notifications = notifications;
  }

  @GetMapping
  PageResponse<NotificationDto> list(@CurrentUser long userId, @RequestParam MultiValueMap<String, String> params) {
    QueryParams q = new QueryParams(params);
    int page = q.page();
    int pageSize = q.pageSize();
    q.finish();
    Instant now = Instant.now();
    List<NotificationDto> items = notifications
        .listVisible(userId, now, pageSize, PageResponse.offset(page, pageSize)).stream()
        .map(NotificationDto::from)
        .toList();
    return new PageResponse<>(items, page, pageSize, notifications.countVisible(userId, now));
  }

  @GetMapping("/unread-count")
  Map<String, Long> unreadCount(@CurrentUser long userId) {
    return Map.of("count", notifications.countUnread(userId, Instant.now()));
  }

  @PostMapping("/read-all")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void readAll(@CurrentUser long userId) {
    notifications.markAllRead(userId, Instant.now());
  }

  @PostMapping("/{id}/read")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void read(@CurrentUser long userId, @PathVariable String id) {
    if (notifications.markRead(userId, Ids.parse(id), Instant.now()) == 0) {
      throw AppException.notFound("Notification not found");
    }
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@CurrentUser long userId, @PathVariable String id) {
    if (notifications.delete(userId, Ids.parse(id), Instant.now()) == 0) {
      throw AppException.notFound("Notification not found");
    }
  }

  @DeleteMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void clearAll(@CurrentUser long userId) {
    notifications.deleteVisible(userId, Instant.now());
  }
}
