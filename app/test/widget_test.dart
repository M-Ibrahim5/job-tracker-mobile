import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app boots into the login screen with the fake backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(),
        child: const JobTrailApp(useGoogleFonts: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('JobTrail'), findsOneWidget);
  });
}
