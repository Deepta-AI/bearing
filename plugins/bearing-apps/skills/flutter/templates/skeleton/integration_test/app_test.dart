import 'package:app/app.dart';
import 'package:app/features/health/health.dart';
import 'package:app/features/health/health_provider.dart';
import 'package:app/features/health/health_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Stands in for the API so the smoke test never needs a network.
class FakeHealthRepository implements HealthRepository {
  @override
  Future<Health> fetch() async => const Health(status: 'ok', version: 'smoke');
}

// One smoke flow through the real App on a device, an emulator or a desktop
// target: `make test-integration` (not part of make check).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots to the health page and shows the API answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthRepositoryProvider.overrideWithValue(FakeHealthRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API health'), findsOneWidget);
    expect(find.text('Status: ok'), findsOneWidget);
    expect(find.text('Version: smoke'), findsOneWidget);
  });
}
