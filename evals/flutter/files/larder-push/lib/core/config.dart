import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Values passed with --dart-define-from-file=config/<flavour>.json.
class AppConfig {
  const AppConfig({
    required this.flavour,
    required this.apiBaseUrl,
    required this.logLevel,
    this.pushSecret = '',
  });

  /// Reads and validates the compile-time defines; throws on a bad value.
  factory AppConfig.fromEnvironment() {
    const flavour = String.fromEnvironment('FLAVOUR');
    const url = String.fromEnvironment('API_BASE_URL');
    const level = String.fromEnvironment('LOG_LEVEL', defaultValue: 'INFO');
    if (!const {'dev', 'staging', 'prod'}.contains(flavour)) {
      throw StateError('FLAVOUR must be dev, staging or prod, got "$flavour"');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an https URL, got "$url"');
    }
    final logLevel = Level.LEVELS.where((l) => l.name == level).firstOrNull;
    if (logLevel == null) {
      throw StateError('LOG_LEVEL "$level" is not a logging level');
    }
    const pushSecret = String.fromEnvironment('PUSH_REGISTRATION_SECRET');
    return AppConfig(
      flavour: flavour,
      apiBaseUrl: url,
      logLevel: logLevel,
      pushSecret: pushSecret,
    );
  }

  final String flavour;
  final String apiBaseUrl;
  final Level logLevel;

  /// Shared secret the devices endpoint checks before storing a push token.
  final String pushSecret;
}

/// Overridden in main with the validated config.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider is set in main'),
);
