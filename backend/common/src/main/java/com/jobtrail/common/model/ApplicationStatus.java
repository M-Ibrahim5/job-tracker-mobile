package com.jobtrail.common.model;

/** Declaration order is the pipeline order (also the MySQL ENUM order used for status sorting). */
public enum ApplicationStatus {
  applied,
  screening,
  interview,
  offer,
  rejected;

  public String label() {
    String name = name();
    return Character.toUpperCase(name.charAt(0)) + name.substring(1);
  }
}
