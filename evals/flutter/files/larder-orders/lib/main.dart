import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/logging.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  configureLogging(config.logLevel);
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const LarderApp(),
    ),
  );
}
