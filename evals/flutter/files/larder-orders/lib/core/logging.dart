import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Routes package:logging records to dart:developer at [level].
void configureLogging(Level level) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
