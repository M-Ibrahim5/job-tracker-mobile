import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../app/providers.dart';

/// Reads the device's IANA timezone name (e.g. `Asia/Kuala_Lumpur`).
typedef TimezoneReader = Future<String> Function();

/// Source of the device timezone sent to `/dashboard` and `/calendar`.
/// Falls back to `UTC` when the platform can't tell. The fake backend ignores
/// the zone, so it never asks the platform (which isn't there in tests).
final deviceTimezoneProvider = Provider<TimezoneReader>(
  (ref) => () async {
    if (ref.read(useFakeBackendProvider)) return 'UTC';
    try {
      return await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      return 'UTC';
    }
  },
);
