import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/utils/date_helpers.dart';
import 'package:jobtrail/core/utils/validators.dart';
import 'package:jobtrail/domain/enums/enums.dart';

void main() {
  group('Validators', () {
    test('requiredText', () {
      expect(Validators.requiredText('  '), isNotNull);
      expect(Validators.requiredText('ok'), isNull);
      expect(Validators.requiredText('a' * 101), isNotNull);
    });

    test('optionalUrl', () {
      expect(Validators.optionalUrl(''), isNull);
      expect(Validators.optionalUrl('https://jobs.example.com/1'), isNull);
      expect(Validators.optionalUrl('ftp://example.com'), isNotNull);
      expect(Validators.optionalUrl('not a url'), isNotNull);
    });

    test('optionalEmail', () {
      expect(Validators.optionalEmail(null), isNull);
      expect(Validators.optionalEmail('a@b.co'), isNull);
      expect(Validators.optionalEmail('a@b'), isNotNull);
    });

    test('appliedDate allows up to one day ahead', () {
      final now = DateTime(2026, 10, 24, 12);
      expect(Validators.appliedDate(DateTime(2026, 10, 25), now: now), isNull);
      expect(
        Validators.appliedDate(DateTime(2026, 10, 26), now: now),
        isNotNull,
      );
    });
  });

  group('DateHelpers.reminderTimes', () {
    final now = DateTime(2026, 10, 24, 12);

    test('computes and sorts future reminders', () {
      final event = DateTime(2026, 10, 26, 10);
      final times = DateHelpers.reminderTimes(event, const [
        Duration(hours: 1),
        Duration(days: 1),
      ], now: now);
      expect(times, [DateTime(2026, 10, 25, 10), DateTime(2026, 10, 26, 9)]);
    });

    test('drops reminders already in the past', () {
      final event = DateTime(2026, 10, 24, 12, 30);
      final times = DateHelpers.reminderTimes(event, const [
        Duration(days: 1),
        Duration(minutes: 15),
      ], now: now);
      expect(times, [DateTime(2026, 10, 24, 12, 15)]);
    });
  });

  test('ApplicationStatus flow', () {
    expect(ApplicationStatus.applied.nextInFlow, ApplicationStatus.screening);
    expect(ApplicationStatus.offer.nextInFlow, isNull);
    expect(ApplicationStatus.screening.isActive, isTrue);
    expect(ApplicationStatus.rejected.isActive, isFalse);
  });
}
