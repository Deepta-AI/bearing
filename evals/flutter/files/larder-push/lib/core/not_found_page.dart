import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Shown for a route the router does not know.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(l10n.notFound)),
    );
  }
}
