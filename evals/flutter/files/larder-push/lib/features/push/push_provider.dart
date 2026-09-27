import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/http.dart';
import '../../router.dart';
import 'push_service.dart';

/// The push service, one per app.
final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(
    ref.watch(dioProvider),
    ref.watch(appConfigProvider),
    ref.watch(routerProvider),
  ),
);
