import 'package:app/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.validate', () {
    test('accepts the dev defaults', () {
      expect(AppConfig.fromEnvironment.flavor, 'dev');
      expect(AppConfig.fromEnvironment.validate(), isEmpty);
    });

    test('accepts a staging https URL', () {
      const config = AppConfig(
        flavor: 'staging',
        apiUrl: 'https://api.qa.example.com',
      );
      expect(config.validate(), isEmpty);
    });

    test('names an unknown flavour', () {
      const config = AppConfig(
        flavor: 'local',
        apiUrl: 'http://localhost:8080',
      );
      expect(config.validate(), [contains('FLAVOR')]);
    });

    test('rejects a URL that is not absolute http(s)', () {
      for (final url in ['localhost:8080', 'ftp://x', '', 'http://']) {
        final config = AppConfig(flavor: 'dev', apiUrl: url);
        expect(config.validate(), [contains('API_URL')], reason: url);
      }
    });

    test('requires https in prod', () {
      const config = AppConfig(
        flavor: 'prod',
        apiUrl: 'http://api.example.com',
      );
      expect(config.isProd, isTrue);
      expect(config.validate(), [contains('https')]);
    });

    test('reports every problem at once', () {
      const config = AppConfig(flavor: 'nope', apiUrl: 'nope');
      expect(config.validate(), hasLength(2));
    });
  });
}
