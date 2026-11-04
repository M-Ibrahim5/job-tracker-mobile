package com.jobtrail.tracker.applications;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.web.Ids;
import com.jobtrail.common.web.PageResponse;
import com.jobtrail.tracker.history.HistoryDto;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/applications")
public class ApplicationController {

  private final ApplicationService service;

  public ApplicationController(ApplicationService service) {
    this.service = service;
  }

  @GetMapping
  PageResponse<ApplicationDto> list(@CurrentUser long userId, @RequestParam MultiValueMap<String, String> params) {
    return service.list(userId, params);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  ApplicationDto create(@CurrentUser long userId, @RequestBody JsonNode body) {
    return service.create(userId, body);
  }

  @GetMapping("/{id}")
  ApplicationDto get(@CurrentUser long userId, @PathVariable String id) {
    return service.get(userId, Ids.parse(id));
  }

  @PatchMapping("/{id}")
  ApplicationDto update(@CurrentUser long userId, @PathVariable String id, @RequestBody JsonNode body) {
    return service.update(userId, Ids.parse(id), body);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@CurrentUser long userId, @PathVariable String id) {
    service.delete(userId, Ids.parse(id));
  }

  @PostMapping("/{id}/status")
  ApplicationService.StatusChangeResult changeStatus(@CurrentUser long userId, @PathVariable String id,
      @RequestBody JsonNode body) {
    return service.changeStatus(userId, Ids.parse(id), body);
  }

  @GetMapping("/{id}/history")
  List<HistoryDto> history(@CurrentUser long userId, @PathVariable String id) {
    return service.history(userId, Ids.parse(id));
  }

  @GetMapping("/{id}/timeline")
  ApplicationService.Timeline timeline(@CurrentUser long userId, @PathVariable String id) {
    return service.timeline(userId, Ids.parse(id));
  }
}
