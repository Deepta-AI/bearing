import 'package:app/features/health/health.dart';
import 'package:dio/dio.dart';

/// What a health call can fail with. Widgets show [message]; nothing above
/// the repository sees a DioException.
sealed class HealthException implements Exception {
  const HealthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The API could not be reached or did not answer in time.
class NetworkException extends HealthException {
  const NetworkException() : super('The API could not be reached');
}

/// The API answered with an error status.
class ApiException extends HealthException {
  ApiException(this.status) : super('The API answered $status');

  final int status;
}

/// The API answered, but not with the shape the model expects.
class InvalidResponseException extends HealthException {
  const InvalidResponseException()
    : super('The API answered with an unexpected body');
}

/// The only place the health endpoint is called. Returns a typed model,
/// throws a typed exception.
class HealthRepository {
  HealthRepository(this._dio);

  final Dio _dio;

  /// GET /healthz.
  Future<Health> fetch() async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>('/healthz');
    } on DioException catch (error) {
      throw switch (error.type) {
        DioExceptionType.badResponse => ApiException(
          error.response?.statusCode ?? 0,
        ),
        _ => const NetworkException(),
      };
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException();
    }
    try {
      return Health.fromJson(data);
    } on Object {
      throw const InvalidResponseException();
    }
  }
}
