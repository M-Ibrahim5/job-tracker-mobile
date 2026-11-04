import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/interviews/application/interview_flow.dart';

void main() {
  group('status suggestion', () {
    test('offered for the first interview of an Applied / Screening job', () {
      for (final s in [
        ApplicationStatus.applied,
        ApplicationStatus.screening,
      ]) {
        expect(
          shouldSuggestInterviewStatus(status: s, existingInterviews: 0),
          isTrue,
          reason: s.name,
        );
      }
    });

    test('not offered once the application has interviews', () {
      expect(
        shouldSuggestInterviewStatus(
          status: ApplicationStatus.applied,
          existingInterviews: 1,
        ),
        isFalse,
      );
    });

    test('not offered from Interview, Offer or Rejected', () {
      for (final s in [
        ApplicationStatus.interview,
        ApplicationStatus.offer,
        ApplicationStatus.rejected,
      ]) {
        expect(
          shouldSuggestInterviewStatus(status: s, existingInterviews: 0),
          isFalse,
          reason: s.name,
        );
      }
    });
  });

  group('schedule helpers', () {
    final now = DateTime(2026, 10, 25, 12);

    test('past, present and future times', () {
      expect(isPastSchedule(DateTime(2026, 10, 25, 11, 59), now), isTrue);
      expect(isPastSchedule(now, now), isTrue);
      expect(isPastSchedule(DateTime(2026, 10, 25, 12, 1), now), isFalse);
    });

    test('combines a date with a time of day', () {
      expect(
        combineDateAndTime(DateTime(2026, 10, 27, 5, 5), 14, 30),
        DateTime(2026, 10, 27, 14, 30),
      );
    });
  });

  group('reminder offsets', () {
    test('labels', () {
      expect(reminderOffsetLabel(const Duration(days: 1)), '1 day before');
      expect(reminderOffsetLabel(const Duration(days: 2)), '2 days before');
      expect(reminderOffsetLabel(const Duration(hours: 1)), '1 hour before');
      expect(reminderOffsetLabel(const Duration(hours: 3)), '3 hours before');
      expect(reminderOffsetLabel(const Duration(minutes: 15)), '15 min before');
      expect(reminderOffsetLabel(const Duration(minutes: 90)), '90 min before');
    });

    test('custom minutes must be 1 … 43200', () {
      expect(validateReminderMinutes(null), isNotNull);
      expect(validateReminderMinutes(0), isNotNull);
      expect(validateReminderMinutes(1), isNull);
      expect(validateReminderMinutes(43200), isNull);
      expect(validateReminderMinutes(43201), isNotNull);
    });

    test('presets are 1 day, 1 hour and 15 minutes', () {
      expect(kPresetReminderOffsets, [
        const Duration(days: 1),
        const Duration(hours: 1),
        const Duration(minutes: 15),
      ]);
    });
  });
}
