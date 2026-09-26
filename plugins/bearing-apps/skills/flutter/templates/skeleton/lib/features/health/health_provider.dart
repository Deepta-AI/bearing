import 'package:app/core/http.dart';
import 'package:app/features/health/health.dart';
import 'package:app/features/health/health_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The repository; tests override it with a fake.
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(dioProvider)),
);

/// The current /healthz answer. `ref.invalidate(healthProvider)` retries.
///
/// Riverpod 3 would otherwise retry a failing provider by itself with
/// backoff; dio already retries transport failures and the page owns the
/// Retry button, so the automatic retry is off here.
final healthProvider = FutureProvider<Health>(
  (ref) => ref.watch(healthRepositoryProvider).fetch(),
  retry: (retryCount, error) => null,
);
