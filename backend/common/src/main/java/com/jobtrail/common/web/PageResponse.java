package com.jobtrail.common.web;

import java.util.List;

/** Paginated list envelope: {@code {items, page, pageSize, total}}. */
public record PageResponse<T>(List<T> items, int page, int pageSize, long total) {

  public static int offset(int page, int pageSize) {
    return Math.toIntExact((long) (page - 1) * pageSize);
  }
}
