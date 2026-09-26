import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration compiled in with `--dart-define-from-file=config/<flavour>.json`.
///
/// The values are constants in the binary and readable from it, so this is
/// configuration, never a secret. [validate] runs at boot so a wrong flavour
/// file stops the app with a message instead of failing on the first request.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiUrl,
    this.verboseLogging = false,
  });

  /// The values from the flavour file, with dev defaults for a bare `flutter run`.
  static const AppConfig fromEnvironment = AppConfig(
    flavor: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiUrl: String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:8080',
    ),
    verboseLogging: bool.fromEnvironment('VERBOSE_LOGGING'),
  );

  /// The flavours a config file may name.
  static const flavors = {'dev', 'staging', 'prod'};

  final String flavor;
  final String apiUrl;
  final bool verboseLogging;

  bool get isProd => flavor == 'prod';

  /// Every problem with this configuration; empty when it is usable.
  List<String> validate() {
    final errors = <String>[];
    if (!flavors.contains(flavor)) {
      errors.add('FLAVOR must be one of ${flavors.join(', ')}, got "$flavor"');
    }
    final uri = Uri.tryParse(apiUrl);
    final isHttp =
        uri != null &&
        uri.isAbsolute &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    if (!isHttp || uri.host.isEmpty) {
      errors.add('API_URL must be an absolute http(s) URL, got "$apiUrl"');
    } else if (isProd && uri.scheme != 'https') {
      errors.add('API_URL must use https in prod, got "$apiUrl"');
    }
    return errors;
  }
}

/// The app's configuration; tests override it with a fake.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment,
);
