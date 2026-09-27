import 'package:dio/dio.dart';

/// The request never got an HTTP answer (offline, timeout, TLS).
class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// The API answered with an error status.
class ApiException implements Exception {
  const ApiException(this.status, this.code);
  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Maps a dio failure to one of the typed exceptions above.
Exception mapDioError(DioException e) {
  final response = e.response;
  if (response == null) {
    return NetworkException(e.type.name);
  }
  final body = response.data;
  var code = 'unknown';
  if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
    code = (body['error'] as Map<String, dynamic>)['code'] as String? ?? code;
  }
  return ApiException(response.statusCode ?? 0, code);
}
