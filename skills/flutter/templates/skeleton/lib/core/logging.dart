import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Routes package:logging to dart:developer so DevTools shows every line.
///
/// Nothing in the app calls print. Nothing sensitive is ever logged: the
/// release build keeps these lines, and a device log is not private.
void configureLogging({required bool verbose}) {
  Logger.root.level = verbose ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
