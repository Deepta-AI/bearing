import 'package:app/core/config.dart';
import 'package:app/core/http.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_adapter.dart';

const config = AppConfig(flavor: 'dev', apiUrl: 'http://api.test');

Dio clientWith(FakeAdapter adapter, {int maxRetries = 2}) {
  final dio = createDio(config);
  dio.httpClientAdapter = adapter;
  dio.interceptors
    ..removeWhere((interceptor) => interceptor is RetryInterceptor)
    ..add(RetryInterceptor(dio, maxRetries: maxRetries, delay: (_) async {}));
  return dio;
}

void main() {
  group('createDio', () {
    test('uses the configured base URL, timeouts and JSON', () {
      final dio = createDio(config);

      expect(dio.options.baseUrl, 'http://api.test');
      expect(dio.options.connectTimeout, const Duration(seconds: 5));
      expect(dio.options.receiveTimeout, const Duration(seconds: 10));
      expect(dio.options.headers['accept'], 'application/json');
      expect(dio.interceptors.whereType<RequestIdInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<LoggingInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<RetryInterceptor>(), hasLength(1));
    });
  });

  group('RequestIdInterceptor', () {
    test('adds a request id and keeps one that is already set', () async {
      final adapter = FakeAdapter((_) async => json('{}'));
      final dio = clientWith(adapter);

      await dio.get<dynamic>('/a');
      await dio.get<dynamic>(
        '/b',
        options: Options(headers: {'x-request-id': 'given'}),
      );

      final first = adapter.requests[0].headers['x-request-id'];
      expect(
        first,
        isA<String>().having((id) => id.length, 'length', greaterThan(8)),
      );
      expect(adapter.requests[1].headers['x-request-id'], 'given');
    });

    test('mints distinct ids', () {
      final interceptor = RequestIdInterceptor();

      expect(interceptor.newId(), isNot(interceptor.newId()));
    });
  });

  group('RetryInterceptor', () {
    test('retries a GET after a 503 and returns the later answer', () async {
      var calls = 0;
      final adapter = FakeAdapter((_) async {
        calls += 1;
        return calls == 1
            ? json('{"error":"down"}', status: 503)
            : json('{"ok":true}');
      });
      final dio = clientWith(adapter);

      final response = await dio.get<Map<String, dynamic>>('/thing');

      expect(response.statusCode, 200);
      expect(calls, 2);
      expect(
        adapter.requests.last.headers['x-request-id'],
        adapter.requests.first.headers['x-request-id'],
      );
    });

    test('retries a connection error up to the limit, then fails', () async {
      var calls = 0;
      final adapter = FakeAdapter((options) async {
        calls += 1;
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        );
      });
      final dio = clientWith(adapter, maxRetries: 2);

      await expectLater(
        dio.get<dynamic>('/thing'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 3);
    });

    test('never retries a POST', () async {
      var calls = 0;
      final adapter = FakeAdapter((_) async {
        calls += 1;
        return json('{"error":"down"}', status: 503);
      });
      final dio = clientWith(adapter);

      await expectLater(
        dio.post<dynamic>('/thing'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });

    test('does not retry a client error', () async {
      var calls = 0;
      final adapter = FakeAdapter((_) async {
        calls += 1;
        return json('{"error":"nope"}', status: 404);
      });
      final dio = clientWith(adapter);

      await expectLater(
        dio.get<dynamic>('/thing'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });
  });
}
