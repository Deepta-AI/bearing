import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned answer for one method and path.
class FakeReply {
  const FakeReply(this.status, this.body);
  final int status;
  final Object? body;
}

/// Answers dio requests from a table; records every request it saw.
class FakeAdapter implements HttpClientAdapter {
  final Map<String, List<FakeReply>> replies = {};
  final List<RequestOptions> requests = [];

  /// Queues [reply] for "METHOD /path"; the last reply repeats.
  void on(String method, String path, FakeReply reply) {
    replies.putIfAbsent('$method $path', () => []).add(reply);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queue = replies['${options.method} ${options.path}'];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"error":{"code":"no_fake"}}', 404,
          headers: _json);
    }
    final reply = queue.length > 1 ? queue.removeAt(0) : queue.first;
    return ResponseBody.fromString(jsonEncode(reply.body), reply.status,
        headers: _json);
  }

  @override
  void close({bool force = false}) {}

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };
}

/// A Dio on [adapter] with the app's base options but no retry delay.
Dio testDio(FakeAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://api.test.larder.example'))
    ..httpClientAdapter = adapter;
}
