import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'config.dart';

final _log = Logger('http');
var _nextRequest = 0;

/// The one Dio instance: base URL, timeouts and the interceptors.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'accept': 'application/json'},
    ),
  );
  dio.interceptors.addAll([
    RequestIdInterceptor(),
    LoggingInterceptor(),
    RetryInterceptor(dio),
  ]);
  return dio;
});

/// Adds an x-request-id header so a request can be found in the API logs.
class RequestIdInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['x-request-id'] ??=
        '${DateTime.now().microsecondsSinceEpoch}-${_nextRequest++}';
    handler.next(options);
  }
}

/// Logs method, path, status and duration; never headers or bodies.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['startedAt'] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log.fine(_line(response.requestOptions, response.statusCode));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.info(_line(err.requestOptions, err.response?.statusCode));
    handler.next(err);
  }

  String _line(RequestOptions o, int? status) {
    final started = o.extra['startedAt'] as DateTime?;
    final ms = started == null
        ? '?'
        : DateTime.now().difference(started).inMilliseconds.toString();
    return '${o.method} ${o.path} ${status ?? '-'} ${ms}ms';
  }
}

/// Retries transient failures (timeouts, connection errors, 5xx) up to
/// [maxAttempts] times with a growing delay.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxAttempts = 3});

  final Dio _dio;
  final int maxAttempts;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['attempt'] as int?) ?? 1;
    final transient =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
    if (!transient || attempt >= maxAttempts) {
      return handler.next(err);
    }
    await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    final options = err.requestOptions..extra['attempt'] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
