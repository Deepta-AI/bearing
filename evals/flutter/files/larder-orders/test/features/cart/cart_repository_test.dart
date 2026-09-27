import 'package:app/core/errors.dart';
import 'package:app/features/cart/cart_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late CartRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    repo = CartRepository(testDio(adapter));
  });

  test('parses the cart and totals it in minor units', () async {
    adapter.on('GET', '/cart', const FakeReply(200, {
      'currency': 'INR',
      'items': [
        {'sku': 'atta-5kg', 'name': 'Atta', 'quantity': 2, 'unit_price_minor': 28900},
      ],
    }));
    final cart = await repo.fetch();
    expect(cart.items.single.sku, 'atta-5kg');
    expect(cart.totalMinor, 57800);
  });

  test('maps an API error to ApiException with its code', () async {
    adapter.on('GET', '/cart', const FakeReply(401, {
      'error': {'code': 'unauthenticated', 'message': 'sign in'},
    }));
    expect(
      repo.fetch(),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 401)
          .having((e) => e.code, 'code', 'unauthenticated')),
    );
  });
}
