import 'dart:developer' as developer;
import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('PettyCashApp');

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        sequenceNumber: record.sequenceNumber,
        level: record.level.value,
        name: record.loggerName,
        zone: record.zone,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.info(message);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.warning(message);
  }

  static void severe(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.severe(message);
  }

  static void fine(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.fine(message);
  }

  static void finer(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.finer(message);
  }
}