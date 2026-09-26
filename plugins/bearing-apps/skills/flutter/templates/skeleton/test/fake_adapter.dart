import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers dio without a socket. Each call goes through [handler], which
/// returns a body or throws a DioException, so tests drive the client
/// through the same interceptors production uses.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON body with the given status.
ResponseBody json(String body, {int status = 200}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
