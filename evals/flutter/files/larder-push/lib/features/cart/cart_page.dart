import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cart_provider.dart';

/// The cart: its lines and the total.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle)),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorGeneric),
              TextButton(
                onPressed: () => ref.invalidate(cartProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (cart) {
          if (cart.items.isEmpty) {
            return Center(child: Text(l10n.cartEmpty));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, i) {
                    final line = cart.items[i];
                    return ListTile(
                      key: ValueKey(line.sku),
                      title: Text(line.name),
                      subtitle: Text(l10n.quantity(line.quantity)),
                      trailing: Text(
                        formatMoney(
                          line.quantity * line.unitPriceMinor,
                          cart.currency,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.cartTotal(formatMoney(cart.totalMinor, cart.currency)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
