package com.jobtrail.common.db;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Builds {@code UPDATE table SET col = :p0, ... WHERE ...} for PATCH-style partial updates.
 * Column names come from code (never from request data); values are always bound.
 */
public final class UpdateBuilder {

  private final String table;
  private final Map<String, Object> sets = new LinkedHashMap<>();

  private UpdateBuilder(String table) {
    this.table = table;
  }

  public static UpdateBuilder table(String table) {
    return new UpdateBuilder(table);
  }

  public UpdateBuilder set(String column, Object value) {
    sets.put(column, Db.param(value));
    return this;
  }

  /** Same as {@link #set} for a JSON column (value is a JSON string). */
  public UpdateBuilder setJson(String column, String json) {
    sets.put(column + "#json", json);
    return this;
  }

  public boolean isEmpty() {
    return sets.isEmpty();
  }

  /** Runs the update with {@code whereSql} (using :wN-free named params from {@code whereParams}). */
  public int execute(JdbcClient jdbc, String whereSql, Map<String, Object> whereParams) {
    if (sets.isEmpty()) {
      return 0;
    }
    StringBuilder sql = new StringBuilder("UPDATE ").append(table).append(" SET ");
    Map<String, Object> params = new LinkedHashMap<>(whereParams);
    int i = 0;
    for (Map.Entry<String, Object> entry : sets.entrySet()) {
      String key = entry.getKey();
      boolean json = key.endsWith("#json");
      String column = json ? key.substring(0, key.length() - 5) : key;
      String name = "p" + i++;
      if (i > 1) {
        sql.append(", ");
      }
      sql.append(column).append(" = ").append(json ? "CAST(:" + name + " AS JSON)" : ":" + name);
      params.put(name, entry.getValue());
    }
    sql.append(" WHERE ").append(whereSql);
    return jdbc.sql(sql.toString()).params(params).update();
  }
}
