import 'dart:async';

import 'package:app/features/health/health.dart';
import 'package:app/features/health/health_page.dart';
import 'package:app/features/health/health_provider.dart';
import 'package:app/features/health/health_repository.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers each fetch from a queue so a test can script loading, failure and recovery.
class FakeHealthRepository implements HealthRepository {
  FakeHealthRepository(this.answers);

  final List<FutureOr<Health> Function()> answers;
  int calls = 0;

  @override
  Future<Health> fetch() async {
    final answer = answers[calls.clamp(0, answers.length - 1)];
    calls += 1;
    return answer();
  }
}

Future<void> pumpPage(WidgetTester tester, HealthRepository repository) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [healthRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HealthPage(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the loading state, then status and version', (
    tester,
  ) async {
    final completer = Completer<Health>();
    final repository = FakeHealthRepository([() => completer.future]);

    await pumpPage(tester, repository);

    expect(find.text('API health'), findsOneWidget);
    expect(find.text('Checking the API'), findsOneWidget);

    completer.complete(const Health(status: 'ok', version: '1.2.3'));
    await tester.pumpAndSettle();

    expect(find.text('Status: ok'), findsOneWidget);
    expect(find.text('Version: 1.2.3'), findsOneWidget);
  });

  testWidgets('shows unknown when the API sends no version', (tester) async {
    final repository = FakeHealthRepository([() => const Health(status: 'ok')]);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Version: unknown'), findsOneWidget);
  });

  testWidgets('shows the error and recovers through Retry', (tester) async {
    final repository = FakeHealthRepository([
      () => throw ApiException(503),
      () => const Health(status: 'ok'),
    ]);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('The API answered 503'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Status: ok'), findsOneWidget);
    expect(repository.calls, 2);
  });
}
