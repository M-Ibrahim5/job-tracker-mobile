import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/reminder_setup.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  if (kReleaseMode) {
    final problem = AppConfig.releaseUrlProblem();
    if (problem != null) throw StateError(problem);
  }
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...localNotificationOverrides(),
      ],
      child: const JobTrailApp(),
    ),
  );
}
