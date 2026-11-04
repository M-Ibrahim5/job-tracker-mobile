import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/device_timezone.dart';
import '../../../domain/models/dashboard_data.dart';
import '../../applications/application/application_providers.dart';
import '../../interviews/application/interviews_providers.dart';

/// Aggregates for the dashboard. Reloads when applications, interviews or all
/// data change.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  ref.watch(applicationsRevisionProvider);
  ref.watch(interviewsRevisionProvider);
  final timezone = await ref.read(deviceTimezoneProvider)();
  return ref.read(dashboardRepositoryProvider).load(timezone: timezone);
});

/// Clock used for greeting and relative times; replace in tests.
final dashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
