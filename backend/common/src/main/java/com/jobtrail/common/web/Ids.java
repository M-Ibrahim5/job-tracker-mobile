package com.jobtrail.common.web;

import com.jobtrail.common.error.AppException;
import java.util.regex.Pattern;

public final class Ids {

  private static final Pattern ID = Pattern.compile("^[1-9]\\d{0,17}$");

  private Ids() {}

  /** Route ids that are not plain positive integers can never exist, so they are 404s. */
  public static long parse(String raw) {
    if (raw == null || !ID.matcher(raw).matches()) {
      throw AppException.notFound("Not found");
    }
    return Long.parseLong(raw);
  }
}
