import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/services/biometric_service.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';
import 'package:jobtrail/features/auth/application/biometric_controller.dart';

class _Sensor implements BiometricAuthenticator {
  bool recognised = true;
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async => recognised;
}

void main() {
  late _Sensor sensor;
  late MemoryDeviceTokenStore store;
  late FakeBackend backend;
  late ProviderContainer container;

  setUp(() {
    sensor = _Sensor();
    store = MemoryDeviceTokenStore();
    backend = FakeBackend(latency: Duration.zero);
    backend.currentUser = backend.usersByEmail[kFakeEmail];
    container = ProviderContainer(
      overrides: [
        useFakeBackendProvider.overrideWithValue(true),
        fakeBackendProvider.overrideWithValue(backend),
        biometricAuthenticatorProvider.overrideWithValue(sensor),
        deviceTokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  BiometricActions actions() => container.read(biometricActionsProvider);

  test(
    'enable needs a scan and the right password, and stores a token',
    () async {
      sensor.recognised = false;
      expect(await actions().enable(password: kFakePassword), isFalse);
      expect(await store.read(), isNull);

      sensor.recognised = true;
      await expectLater(
        actions().enable(password: 'wrong-password'),
        throwsA(isA<Failure>()),
      );
      expect(await store.read(), isNull);

      expect(await actions().enable(password: kFakePassword), isTrue);
      final token = await store.read();
      expect(token, isNotNull);
      // The password itself is never what is kept.
      expect(token, isNot(contains(kFakePassword)));
      final status = await container.read(biometricStatusProvider.future);
      expect(status.canSignIn, isTrue);
    },
  );

  test('signIn needs a recognised fingerprint', () async {
    await actions().enable(password: kFakePassword);
    backend.currentUser = null;
    await container.read(authControllerProvider.future);

    sensor.recognised = false;
    expect(await actions().signIn(), isFalse);
    expect(backend.currentUser, isNull);

    sensor.recognised = true;
    expect(await actions().signIn(), isTrue);
    expect(
      container.read(authControllerProvider).value,
      isA<AuthAuthenticated>(),
    );
  });

  test('a token the server rejects is forgotten', () async {
    await store.save('revoked-token');
    await container.read(authControllerProvider.future);

    await expectLater(actions().signIn(), throwsA(isA<UnauthorizedFailure>()));
    expect(await store.read(), isNull);
  });

  test('disable revokes the token on the server and forgets it', () async {
    await actions().enable(password: kFakePassword);
    final token = (await store.read())!;
    expect(backend.deviceTokens, contains(token));

    await actions().disable();
    expect(await store.read(), isNull);
    expect(backend.deviceTokens, isNot(contains(token)));
  });

  test('a password change re-enrols the phone with a fresh token', () async {
    await actions().enable(password: kFakePassword);
    final old = (await store.read())!;
    // The server revokes every device token when the password changes.
    backend.deviceTokens.clear();

    await actions().passwordChanged(kFakePassword);
    final fresh = await store.read();
    expect(fresh, isNotNull);
    expect(fresh, isNot(old));
    expect(backend.deviceTokens, contains(fresh));
  });
}
