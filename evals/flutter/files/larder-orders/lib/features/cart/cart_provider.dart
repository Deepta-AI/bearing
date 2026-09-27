import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http.dart';
import 'cart.dart';
import 'cart_repository.dart';

/// The cart repository.
final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(dioProvider)),
);

/// The current cart. The page's retry button owns retries, so Riverpod's
/// own automatic retry is off.
final cartProvider = FutureProvider.autoDispose<Cart>(
  (ref) => ref.watch(cartRepositoryProvider).fetch(),
  retry: (_, _) => null,
);
