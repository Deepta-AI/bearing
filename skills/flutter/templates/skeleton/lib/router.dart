import 'package:app/core/not_found_page.dart';
import 'package:app/features/health/health_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every route by name. Navigate with `context.goNamed(HealthPage.routeName)`,
/// never with a string path built at runtime. Deep-link parameters are
/// validated in the page that reads them and never grant access.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: HealthPage.routeName,
        builder: (context, state) => const HealthPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundPage(location: state.uri.toString()),
  );
});
