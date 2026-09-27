import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/logging.dart';
import 'features/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  configureLogging(config.logLevel);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(handleBackgroundOrderUpdate);
  // Ask up front so order updates work from the first order.
  await FirebaseMessaging.instance.requestPermission();
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const LarderApp(),
    ),
  );
}
