package com.jobtrail.common.model;

public enum InterviewType {
  phone("Phone"),
  video("Video"),
  onsite("Onsite"),
  technical("Technical"),
  hr("HR"),
  finalRound("Final round"),
  other("Other");

  private final String label;

  InterviewType(String label) {
    this.label = label;
  }

  public String label() {
    return label;
  }
}
