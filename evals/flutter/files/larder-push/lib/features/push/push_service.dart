import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../core/config.dart';

final _log = Logger('push');

/// Runs in a background isolate when an order update arrives while the
/// app is in the background or closed, so the update is on record before
/// the user opens the app.
Future<void> handleBackgroundOrderUpdate(RemoteMessage message) async {
  await Firebase.initializeApp();
  _log.fine('order update ${message.data['order_id']} arrived in background');
}

/// Registers this device for order update pushes and opens the screen a
/// tapped notification points at.
class PushService {
  PushService(this._dio, this._config, this._router);

  final Dio _dio;
  final AppConfig _config;
  final GoRouter _router;

  /// Registers the token with the API and listens for taps.
  Future<void> start() async {
    final token = await FirebaseMessaging.instance.getToken();
    _log.info('Registered for push with token $token');
    try {
      await _dio.post<void>(
        '/devices',
        data: {'token': token, 'platform': defaultTargetPlatform.name},
        options: Options(headers: {'x-push-secret': _config.pushSecret}),
      );
    } on DioException catch (e) {
      _log.warning('device registration failed', e);
    }
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final link = message.data['link'] as String?;
      if (link != null) {
        _router.go(link);
      }
    });
  }
}
