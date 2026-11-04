import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/config/app_config.dart';

void main() {
  group('releaseUrlProblem', () {
    test('https is fine', () {
      expect(
        AppConfig.releaseUrlProblem(
          url: 'https://api.example.com/api/v1',
          fake: false,
          allowInsecure: false,
        ),
        isNull,
      );
    });

    test('plain http is refused', () {
      expect(
        AppConfig.releaseUrlProblem(
          url: 'http://localhost:3000/api/v1',
          fake: false,
          allowInsecure: false,
        ),
        contains('https://'),
      );
    });

    test('the fake backend and an explicit opt-in are allowed', () {
      expect(
        AppConfig.releaseUrlProblem(
          url: 'http://x',
          fake: true,
          allowInsecure: false,
        ),
        isNull,
      );
      expect(
        AppConfig.releaseUrlProblem(
          url: 'http://x',
          fake: false,
          allowInsecure: true,
        ),
        isNull,
      );
    });
  });
}
