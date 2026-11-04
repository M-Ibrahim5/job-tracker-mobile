package com.jobtrail.common.json;

import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import java.util.List;

/** (De)serialises the JSON integer arrays stored in {@code reminder_offsets} style columns. */
public final class IntList {

  private static final ObjectMapper MAPPER = new ObjectMapper();
  private static final TypeReference<List<Integer>> TYPE = new TypeReference<>() {};

  private IntList() {}

  public static String toJson(List<Integer> values) {
    try {
      return MAPPER.writeValueAsString(values);
    } catch (JacksonException e) {
      throw new IllegalStateException(e);
    }
  }

  public static List<Integer> fromJson(String json) {
    if (json == null || json.isBlank()) {
      return List.of();
    }
    try {
      return MAPPER.readValue(json, TYPE);
    } catch (JacksonException e) {
      throw new IllegalStateException("Corrupt integer array column: " + json, e);
    }
  }
}
