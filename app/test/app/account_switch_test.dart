import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/auth/application/auth_controller.dart';
import 'package:jobtrail/features/calendar/application/calendar_providers.dart';
import 'package:jobtrail/features/interviews/application/interviews_providers.dart';

/// One process-wide provider scope outlives a sign-out, so data cached for one
/// account must not be shown to the next account that signs in.
void main() {
  late FakeBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = FakeBackend(latency: Duration.zero);
    backend.currentUser = backend.usersByEmail[kFakeEmail];
    container = ProviderContainer(
      overrides: [
        useFakeBackendProvider.overrideWithValue(true),
        fakeBackendProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> switchToAnotherAccount() async {
    final auth = container.read(authControllerProvider.notifier);
    await auth.signOut();
    // The fake backend shares its data between users; empty it to stand for
    // an account that has none of the previous account's records.
    backend.applications.clear();
    backend.interviews.clear();
    await auth.signUp(
      fullName: 'Other Person',
      email: 'other@example.com',
      password: 'Passw0rd!',
    );
  }

  test('the application list is reloaded for the next account', () async {
    await container.read(authControllerProvider.future);
    final before = await container.read(applicationListProvider.future);
    expect(before.items, isNotEmpty);

    await switchToAnotherAccount();

    final after = await container.read(applicationListProvider.future);
    expect(after.items, isEmpty);
  });

  test('the interview lists are reloaded for the next account', () async {
    await container.read(authControllerProvider.future);
    final before = await container.read(
      interviewListProvider(InterviewScope.upcoming).future,
    );
    expect(before.items, isNotEmpty);

    await switchToAnotherAccount();

    final after = await container.read(
      interviewListProvider(InterviewScope.upcoming).future,
    );
    expect(after.items, isEmpty);
  });

  test('calendar events and the open timeline are dropped', () async {
    await container.read(authControllerProvider.future);
    final application = (await container.read(
      applicationListProvider.future,
    )).items.first;
    container.read(timelineApplicationProvider.notifier).state = application;
    final now = DateTime.now();
    await container.read(calendarEventsProvider.notifier).ensure([
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
    ]);
    expect(container.read(calendarEventsProvider).months, isNotEmpty);

    await switchToAnotherAccount();

    expect(container.read(timelineApplicationProvider), isNull);
    expect(container.read(calendarEventsProvider).months, isEmpty);
  });

  test('a search filter does not carry over to the next account', () async {
    await container.read(authControllerProvider.future);
    container.read(applicationFilterProvider.notifier).state =
        const ApplicationFilter(query: 'Acme');

    await switchToAnotherAccount();

    expect(container.read(applicationFilterProvider).query, isEmpty);
  });
}
