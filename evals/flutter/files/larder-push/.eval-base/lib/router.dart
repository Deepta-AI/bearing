import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/not_found_page.dart';
import 'features/cart/cart_page.dart';
import 'features/profile/profile_page.dart';

/// Route names; navigate with goNamed or pushNamed, never a built path.
abstract final class Routes {
  static const profile = 'profile';
  static const cart = 'cart';
}

/// The app's router.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        name: Routes.profile,
        builder: (_, _) => const ProfilePage(),
        routes: [
          GoRoute(
            path: 'cart',
            name: Routes.cart,
            builder: (_, _) => const CartPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, _) => const NotFoundPage(),
  );
});
