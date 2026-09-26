import 'package:app/features/health/health.dart';
import 'package:app/features/health/health_provider.dart';
import 'package:app/features/health/health_repository.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the API's health with loading, error (with retry) and data states.
/// Layout only: the state lives in [healthProvider].
class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  static const routeName = 'health';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final health = ref.watch(healthProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.healthTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: health.when(
                    loading: () => _Loading(label: l10n.healthChecking),
                    error: (error, _) => _Failure(
                      message: error is HealthException
                          ? error.message
                          : l10n.unexpectedError,
                      onRetry: () => ref.invalidate(healthProvider),
                    ),
                    data: (data) => _Details(health: data),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.health});

  final Health health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${l10n.healthStatus}: ${health.status}'),
        Text('${l10n.healthVersion}: ${health.version ?? l10n.unknown}'),
      ],
    );
  }
}
