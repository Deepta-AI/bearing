import 'package:app/app.dart';
import 'package:app/core/config.dart';
import 'package:app/core/logging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Boot only: check the compiled-in configuration, wire logging, run the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment;
  final errors = config.validate();
  if (errors.isNotEmpty) {
    throw StateError('invalid configuration: ${errors.join('; ')}');
  }
  configureLogging(verbose: config.verboseLogging || !config.isProd);
  runApp(const ProviderScope(child: App()));
}
