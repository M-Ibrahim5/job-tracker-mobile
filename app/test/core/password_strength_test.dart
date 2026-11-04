import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/utils/password_strength.dart';
import 'package:jobtrail/core/utils/validators.dart';

void main() {
  group('passwordStrength', () {
    test('empty has no segments', () {
      expect(passwordStrength(''), PasswordStrength.empty);
      expect(PasswordStrength.empty.segments, 0);
    });

    test('anything under 8 characters is weak, whatever it contains', () {
      expect(passwordStrength('a'), PasswordStrength.weak);
      expect(passwordStrength('Ab1!'), PasswordStrength.weak);
      expect(passwordStrength('Ab1!xyz'), PasswordStrength.weak);
    });

    test('length alone is weak', () {
      expect(passwordStrength('abcdefgh'), PasswordStrength.weak);
    });

    test('a digit or a symbol adds a level', () {
      expect(passwordStrength('abcdefg1'), PasswordStrength.fair);
      expect(passwordStrength('abcdefg!'), PasswordStrength.fair);
    });

    test('digit + symbol is good', () {
      expect(passwordStrength('abcdef1!'), PasswordStrength.good);
    });

    test('mixed case also counts', () {
      expect(passwordStrength('Abcdefgh'), PasswordStrength.fair);
      expect(passwordStrength('Abcdef1!'), PasswordStrength.strong);
    });

    test('segments grow with strength', () {
      expect(
        [
          PasswordStrength.weak,
          PasswordStrength.fair,
          PasswordStrength.good,
          PasswordStrength.strong,
        ].map((s) => s.segments),
        [1, 2, 3, 4],
      );
    });
  });

  group('Validators password rules', () {
    test('newPassword needs 8 chars, a digit and a symbol', () {
      expect(Validators.newPassword('Abcdef1!'), isNull);
      expect(Validators.newPassword('Abcdefg1'), isNotNull);
      expect(Validators.newPassword('Abcdefg!'), isNotNull);
      expect(Validators.newPassword('A1!'), isNotNull);
    });

    test('matches compares exactly', () {
      expect(Validators.matches('x', 'x'), isNull);
      expect(Validators.matches('x', 'y'), isNotNull);
    });

    test('requiredEmail', () {
      expect(Validators.requiredEmail(''), isNotNull);
      expect(Validators.requiredEmail('nope'), isNotNull);
      expect(Validators.requiredEmail('a@b.co'), isNull);
    });
  });
}
