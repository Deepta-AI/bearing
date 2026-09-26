import 'dart:math';

import 'package:app/core/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('http');

/// Builds the one Dio the app uses: base URL, timeouts, JSON, interceptors.
Dio createDio(AppConfig config) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.addAll([
    RequestIdInterceptor(),
    LoggingInterceptor(),
    RetryInterceptor(dio),
  ]);
  return dio;
}

/// The app's HTTP client; repositories take it through their constructor.
final dioProvider = Provider<Dio>(
  (ref) => createDio(ref.watch(appConfigProvider)),
);

/// Adds an `x-request-id` so a server log line can be matched to a device.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({Random? random}) : _random = random ?? Random();

  static const header = 'x-request-id';

  final Random _random;

  /// A fresh id: microsecond timestamp plus 32 random bits, both in hex.
  String newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$time-$salt';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(header, newId);
    handler.next(options);
  }
}

/// One line per request: method, path, status, duration. Never a header or a body.
class LoggingInterceptor extends Interceptor {
  static const _startedAt = 'loggingStartedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAt] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log.fine(_line(response.requestOptions, response.statusCode));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.warning(_line(err.requestOptions, err.response?.statusCode, err.type));
    handler.next(err);
  }

  String _line(RequestOptions options, int? status, [DioExceptionType? type]) {
    final started = options.extra[_startedAt];
    final elapsed = started is DateTime
        ? DateTime.now().difference(started).inMilliseconds
        : null;
    final suffix = type == null ? '' : ' ${type.name}';
    return '${options.method} ${options.path} ${status ?? '-'} ${elapsed ?? '-'}ms$suffix';
  }
}

/// Retries idempotent requests on connection failures and 5xx answers,
/// a bounded number of times with exponential backoff. A POST is never retried.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  static const attemptKey = 'retryAttempt';
  static const _idempotent = {'GET', 'HEAD', 'OPTIONS'};

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Future<void> Function(Duration) _delay;

  /// Whether this failure is worth another attempt.
  bool shouldRetry(DioException err) {
    final options = err.requestOptions;
    if (!_idempotent.contains(options.method.toUpperCase())) {
      return false;
    }
    final attempt = options.extra[attemptKey];
    if (attempt is int && attempt >= maxRetries) {
      return false;
    }
    final status = err.response?.statusCode;
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => status != null && status >= 500,
      _ => false,
    };
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!shouldRetry(err)) {
      handler.next(err);
      return;
    }
    final options = err.requestOptions;
    final attempt = (options.extra[attemptKey] as int? ?? 0) + 1;
    options.extra[attemptKey] = attempt;
    await _delay(baseDelay * (1 << (attempt - 1)));
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retried) {
      handler.next(retried);
    }
  }
}
