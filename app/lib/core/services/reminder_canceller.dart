/// Cancels every locally scheduled reminder notification. Session 06
/// overrides `reminderCancellerProvider` with the real scheduler.
abstract interface class ReminderCanceller {
  /// Cancels all scheduled local notifications.
  Future<void> cancelAll();
}

/// Default that does nothing until the scheduler exists.
class NoopReminderCanceller implements ReminderCanceller {
  /// Creates the no-op canceller.
  const NoopReminderCanceller();

  @override
  Future<void> cancelAll() async {}
}
