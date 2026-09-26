import 'package:app/core/config.dart';
import 'package:app/core/http.dart';
import 'package:app/features/health/health.dart';
import 'package:app/features/health/health_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_adapter.dart';

HealthRepository repositoryWith(FakeAdapter adapter) {
  final dio = createDio(
    const AppConfig(flavor: 'dev', apiUrl: 'http://api.test'),
  );
  dio.httpClientAdapter = adapter;
  dio.interceptors.removeWhere(
    (interceptor) => interceptor is RetryInterceptor,
  );
  return HealthRepository(dio);
}

void main() {
  group('HealthRepository.fetch', () {
    test('returns the parsed model', () async {
      final adapter = FakeAdapter(
        (_) async => json('{"status":"ok","version":"1.2.3"}'),
      );

      final health = await repositoryWith(adapter).fetch();

      expect(health, const Health(status: 'ok', version: '1.2.3'));
      expect(adapter.requests.single.path, '/healthz');
    });

    test('maps an error status to ApiException', () async {
      final adapter = FakeAdapter(
        (_) async => json('{"error":"down"}', status: 503),
      );

      await expectLater(
        repositoryWith(adapter).fetch(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 503)),
      );
    });

    test('maps a connection failure to NetworkException', () async {
      final adapter = FakeAdapter((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        );
      });

      await expectLater(
        repositoryWith(adapter).fetch(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('rejects a body that is not the model', () async {
      for (final body in ['[]', '{"status":42}', '"text"']) {
        final adapter = FakeAdapter((_) async => json(body));

        await expectLater(
          repositoryWith(adapter).fetch(),
          throwsA(isA<InvalidResponseException>()),
          reason: body,
        );
      }
    });
  });
}
