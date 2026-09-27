import 'package:app/core/errors.dart';
import 'package:app/features/cart/cart.dart';
import 'package:app/features/cart/cart_page.dart';
import 'package:app/features/cart/cart_provider.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Future<Cart> Function() load) {
  return ProviderScope(
    overrides: [cartProvider.overrideWith((ref) => load())],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CartPage(),
    ),
  );
}

void main() {
  testWidgets('shows lines and the total', (tester) async {
    await tester.pumpWidget(_app(() async => const Cart(
          currency: 'INR',
          items: [
            CartLine(sku: 'atta-5kg', name: 'Atta', quantity: 2, unitPriceMinor: 28900),
          ],
        )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Atta'), findsOneWidget);
    expect(find.text('Total ₹578.00'), findsOneWidget);
  });

  testWidgets('shows an error with a retry that reloads', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(() async {
      calls++;
      throw const NetworkException('offline');
    }));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
