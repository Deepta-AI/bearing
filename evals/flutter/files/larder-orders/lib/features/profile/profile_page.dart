import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../router.dart';

/// The profile hub: links to the user's cart and account screens.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: Text(l10n.profileCart),
            onTap: () => context.goNamed(Routes.cart),
          ),
        ],
      ),
    );
  }
}
