package com.jobtrail.tracker.settings;

/** Reads a user's reminder preferences from the user service. */
public interface UserSettingsClient {

  /** Never fails: if the user service is unreachable the documented defaults apply. */
  ReminderPrefs prefsFor(long userId);
}
