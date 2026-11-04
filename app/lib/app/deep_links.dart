import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_notification.dart';

/// Path waiting to be opened (set by a tapped notification, consumed once the
/// user is signed in and the router is ready).
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final _safeLink = RegExp(r'^/(interviews|applications)/\d+$');

/// Whether [path] is a deep link the app is willing to open.
bool isSafeDeepLink(String? path) => path != null && _safeLink.hasMatch(path);

/// Screen to open when [n] is tapped in the Alerts list, or null.
String? deepLinkForNotification(AppNotification n) {
  if (n.relatedInterviewId != null) {
    return '/interviews/${n.relatedInterviewId}';
  }
  if (n.relatedApplicationId != null) {
    return '/applications/${n.relatedApplicationId}';
  }
  return null;
}
