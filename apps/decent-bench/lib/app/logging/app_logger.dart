import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../app_support_paths.dart';
import '../../features/workspace/domain/app_config.dart';

abstract class AppLogger {
  const AppLogger();

  String get logDirectoryPath;
  String get sessionLogFilePath;

  Future<void> initialize({LogVerbosity? minimumLevel});

  void updateMinimumLevel(LogVerbosity minimumLevel);

  void log({
    required LogVerbosity level,
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  });

  void debug({
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
  }) {
    log(
      level: LogVerbosity.debug,
      category: category,
      message: message,
      operation: operation,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
    );
  }

  void info({
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
  }) {
    log(
      level: LogVerbosity.information,
      category: category,
      message: message,
      operation: operation,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
    );
  }

  void warning({
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      level: LogVerbosity.warning,
      category: category,
      message: message,
      operation: operation,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error({
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      level: LogVerbosity.error,
      category: category,
      message: message,
      operation: operation,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logQueryTiming({
    required String databasePath,
    required String sql,
    required int rowCount,
    required int elapsedNanos,
    String operation = 'query.complete',
    int? rowsAffected,
    Map<String, Object?>? details,
  }) {
    info(
      category: 'query',
      operation: operation,
      message: 'SQL execution timing recorded.',
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      details: details,
    );
  }

  Future<void> dispose();
}

class NoOpAppLogger extends AppLogger {
  const NoOpAppLogger();

  @override
  String get logDirectoryPath => '';
  @override
  String get sessionLogFilePath => '';

  @override
  Future<void> initialize({LogVerbosity? minimumLevel}) async {}

  @override
  void updateMinimumLevel(LogVerbosity minimumLevel) {}

  @override
  void log({
    required LogVerbosity level,
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  Future<void> dispose() async {}
}

class ClefAppLogger extends AppLogger {
  ClefAppLogger({
    String? logDirectory,
    String? sessionLogFilePath,
  }) : _logDirectory =
            logDirectory ?? AppSupportPaths.resolveLogDirectoryPath('logs'),
       _sessionLogFilePath = sessionLogFilePath;

  final String _logDirectory;
  String? _sessionLogFilePath;
  File? _logFile;
  LogVerbosity _minimumLevel = LogVerbosity.debug;

  @override
  String get logDirectoryPath => _logDirectory;

  @override
  String get sessionLogFilePath => _sessionLogFilePath ?? '';

  @override
  Future<void> initialize({LogVerbosity? minimumLevel}) async {
    if (minimumLevel != null) {
      _minimumLevel = minimumLevel;
    }
    if (_sessionLogFilePath == null) {
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      _sessionLogFilePath = p.join(_logDirectory, 'decent-bench-$timestamp.log');
    }
    final file = File(_sessionLogFilePath!);
    await file.parent.create(recursive: true);
    _logFile = file;
    info(
      category: 'app',
      message: 'Application session started.',
      details: <String, Object?>{
        'log_file': _sessionLogFilePath,
        'minimum_level': _minimumLevel.name,
        'platform': Platform.operatingSystem,
      },
    );
  }

  @override
  void updateMinimumLevel(LogVerbosity minimumLevel) {
    _minimumLevel = minimumLevel;
  }

  @override
  void log({
    required LogVerbosity level,
    required String category,
    required String message,
    String? operation,
    String? databasePath,
    String? sql,
    int? rowCount,
    int? rowsAffected,
    int? elapsedNanos,
    Map<String, Object?>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < _minimumLevel.value) {
      return;
    }
    final file = _logFile;
    if (file == null) {
      return;
    }
    final event = <String, Object?>{
      '@t': DateTime.now().toUtc().toIso8601String(),
      '@l': _levelName(level),
      '@mt': message,
      'category': category,
    };
    if (operation != null) event['operation'] = operation;
    if (databasePath != null) event['databasePath'] = databasePath;
    if (sql != null) event['sql'] = sql;
    if (rowCount != null) event['rowCount'] = rowCount;
    if (rowsAffected != null) event['rowsAffected'] = rowsAffected;
    if (elapsedNanos != null) event['elapsedNanos'] = elapsedNanos;
    if (details != null) {
      for (final entry in details.entries) {
        event[entry.key] = entry.value;
      }
    }
    if (error != null) {
      event['error'] = error.toString();
      event['errorType'] = error.runtimeType.toString();
    }
    if (stackTrace != null && stackTrace.toString().isNotEmpty) {
      event['stackTrace'] = stackTrace.toString();
    }
    try {
      file.writeAsStringSync(
        '${jsonEncode(event)}\n',
        mode: FileMode.append,
      );
    } catch (_) {
      debugPrint(
        '[CLEF] Failed to write log entry: $message',
      );
    }
  }

  String _levelName(LogVerbosity level) {
    switch (level) {
      case LogVerbosity.debug:
        return 'Debug';
      case LogVerbosity.information:
        return 'Information';
      case LogVerbosity.warning:
        return 'Warning';
      case LogVerbosity.error:
        return 'Error';
    }
  }

  @override
  Future<void> dispose() async {
    info(
      category: 'app',
      message: 'Application session ended.',
    );
    _logFile = null;
  }
}
