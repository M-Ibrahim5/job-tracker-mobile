import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/constants/application_strings.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/applications/presentation/status_celebration_dialog.dart';

Future<void> _open(WidgetTester tester, ApplicationStatus status) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showStatusCelebration(context, status: status, company: 'Acme'),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('only offer and rejected get a message', () {
    expect(
      [
        for (final s in ApplicationStatus.values)
          if (hasStatusMessage(s)) s,
      ],
      [ApplicationStatus.offer, ApplicationStatus.rejected],
    );
  });

  testWidgets('offer congratulates and can be dismissed', (tester) async {
    await _open(tester, ApplicationStatus.offer);
    expect(find.text(ApplicationStrings.offerTitle), findsOneWidget);
    expect(find.textContaining('Acme'), findsOneWidget);
    await tester.tap(find.text(ApplicationStrings.offerAction));
    await tester.pumpAndSettle();
    expect(find.text(ApplicationStrings.offerTitle), findsNothing);
  });

  testWidgets('rejected shows an encouraging message', (tester) async {
    await _open(tester, ApplicationStatus.rejected);
    expect(find.text(ApplicationStrings.rejectedTitle), findsOneWidget);
    expect(find.textContaining('Acme'), findsOneWidget);
    await tester.tap(find.text(ApplicationStrings.rejectedAction));
    await tester.pumpAndSettle();
    expect(find.text(ApplicationStrings.rejectedTitle), findsNothing);
  });
}
