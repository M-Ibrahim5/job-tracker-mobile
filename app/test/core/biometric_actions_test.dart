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
      await container.read(authControllerProvider.future);
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
    await container.read(authControllerProvider.future);
    await actions().enable(password: kFakePassword);
    backend.currentUser = null;
    container.invalidate(authControllerProvider);
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
    await store.save('revoked-token', userId: 1);
    await container.read(authControllerProvider.future);

    await expectLater(actions().signIn(), throwsA(isA<UnauthorizedFailure>()));
    expect(await store.read(), isNull);
  });

  test('disable revokes the token on the server and forgets it', () async {
    await container.read(authControllerProvider.future);
    await actions().enable(password: kFakePassword);
    final token = (await store.read())!;
    expect(backend.deviceTokens, contains(token));

    await actions().disable();
    expect(await store.read(), isNull);
    expect(backend.deviceTokens, isNot(contains(token)));
  });

  test('a password change re-enrols the phone with a fresh token', () async {
    await container.read(authControllerProvider.future);
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

  test(
    'another account signing in does not inherit fingerprint login',
    () async {
      final auth = container.read(authControllerProvider.notifier);
      await container.read(authControllerProvider.future);
      await actions().enable(password: kFakePassword);
      expect(await store.read(), isNotNull);

      await auth.signOut();
      await auth.signUp(
        fullName: 'Other Person',
        email: 'other@example.com',
        password: 'Passw0rd!',
      );

      // The token belonged to the first account: it is gone, and the fingerprint
      // button cannot sign in as that account any more.
      expect(await store.read(), isNull);
      final status = await container.read(biometricStatusProvider.future);
      expect(status.enabled, isFalse);
      expect(await actions().signIn(), isFalse);
    },
  );

  test('the owner keeps fingerprint login after a password sign-in', () async {
    final auth = container.read(authControllerProvider.notifier);
    await container.read(authControllerProvider.future);
    await actions().enable(password: kFakePassword);

    await auth.signOut();
    await auth.signIn(email: kFakeEmail, password: kFakePassword);

    expect(await store.read(), isNotNull);
    expect(
      (await container.read(biometricStatusProvider.future)).enabled,
      isTrue,
    );
  });

  test(
    'a token saved without an owner is claimed by a fingerprint sign-in',
    () async {
      final first = await container.read(authControllerProvider.future);
      expect(first, isA<AuthAuthenticated>());
      await actions().enable(password: kFakePassword);
      final token = (await store.read())!;
      final owner = (await store.readOwner())!;
      // As saved by an older app version: no owner recorded.
      store = MemoryDeviceTokenStore(token);
      container.updateOverrides([
        useFakeBackendProvider.overrideWithValue(true),
        fakeBackendProvider.overrideWithValue(backend),
        biometricAuthenticatorProvider.overrideWithValue(sensor),
        deviceTokenStoreProvider.overrideWithValue(store),
      ]);
      await container.read(authControllerProvider.notifier).signOut();

      expect(await actions().signIn(), isTrue);
      expect(await store.readOwner(), owner);
    },
  );
}
