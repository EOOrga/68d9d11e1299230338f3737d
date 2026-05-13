import 'package:decloquement_eric_pierre/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const DeploOperationsApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds a task and records audit activity', (tester) async {
    await pumpApp(tester);

    expect(find.text('No tasks yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-task-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'Review intake queue',
    );
    await tester.enterText(find.byKey(const ValueKey('task-owner')), 'Office');
    await tester.enterText(
      find.byKey(const ValueKey('task-due')),
      'Today 14:00',
    );
    await tester.tap(find.byKey(const ValueKey('save-task')));
    await tester.pumpAndSettle();

    expect(find.text('Review intake queue'), findsOneWidget);

    await tester.tap(find.text('Audit'));
    await tester.pumpAndSettle();

    expect(find.text('Task added'), findsOneWidget);
  });

  testWidgets('adds a patient record and opens detail', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-patient')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('patient-name')),
      'Samir T.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('patient-code')),
      'PT-2001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('patient-action')),
      'Confirm documents',
    );
    await tester.enterText(
      find.byKey(const ValueKey('patient-notes')),
      'Waiting for a signed update.',
    );
    await tester.tap(find.byKey(const ValueKey('save-patient')));
    await tester.pumpAndSettle();

    expect(find.text('Samir T.'), findsOneWidget);

    await tester.tap(find.text('Samir T.'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('patient-detail-screen')), findsOneWidget);
    expect(find.text('Confirm documents'), findsOneWidget);
  });

  testWidgets('adds a revenue item to local analytics', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-revenue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('revenue-label')),
      'Invoices',
    );
    await tester.enterText(
      find.byKey(const ValueKey('revenue-amount')),
      '4200',
    );
    await tester.enterText(find.byKey(const ValueKey('revenue-period')), 'May');
    await tester.tap(find.byKey(const ValueKey('save-revenue')));
    await tester.pumpAndSettle();

    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('4 200 MAD'), findsWidgets);
  });
}
