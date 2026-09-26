import 'package:app/features/health/health_page.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Answers any route the router does not know.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.notFoundBody(location)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.goNamed(HealthPage.routeName),
              child: Text(l10n.backHome),
            ),
          ],
        ),
      ),
    );
  }
}
