package com.jobtrail.tracker.interviews;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.time.TimeUtil;
import com.jobtrail.common.web.Ids;
import com.jobtrail.common.web.PageResponse;
import org.springframework.http.HttpStatus;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class InterviewController {

  private final InterviewService service;

  public InterviewController(InterviewService service) {
    this.service = service;
  }

  @PostMapping("/applications/{id}/interviews")
  @ResponseStatus(HttpStatus.CREATED)
  InterviewDto create(@CurrentUser long userId, @PathVariable String id, @RequestBody JsonNode body,
      @RequestHeader(value = "X-Timezone", required = false) String tz) {
    return service.create(userId, Ids.parse(id), body, TimeUtil.zoneOrUtc(tz));
  }

  @GetMapping("/interviews")
  PageResponse<InterviewDto> list(@CurrentUser long userId, @RequestParam MultiValueMap<String, String> params) {
    return service.list(userId, params);
  }

  @GetMapping("/interviews/{id}")
  InterviewDto get(@CurrentUser long userId, @PathVariable String id) {
    return service.get(userId, Ids.parse(id));
  }

  @PatchMapping("/interviews/{id}")
  InterviewDto update(@CurrentUser long userId, @PathVariable String id, @RequestBody JsonNode body,
      @RequestHeader(value = "X-Timezone", required = false) String tz) {
    return service.update(userId, Ids.parse(id), body, TimeUtil.zoneOrUtc(tz));
  }

  @DeleteMapping("/interviews/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@CurrentUser long userId, @PathVariable String id) {
    service.delete(userId, Ids.parse(id));
  }
}
