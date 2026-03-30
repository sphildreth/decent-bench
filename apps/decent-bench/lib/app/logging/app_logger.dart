import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_support_paths.dart';
import '../../features/workspace/domain/app_config.dart';
import '../../features/workspace/infrastructure/decentdb_bridge.dart';

abstract class AppLogger {
  const AppLogger();

  String get logDatabasePath;

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
  String get logDatabasePath => AppSupportPaths.resolveLogDatabasePath();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize({LogVerbosity? minimumLevel}) async {}

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
  void updateMinimumLevel(LogVerbosity minimumLevel) {}
}

class DecentBenchLogger extends AppLogger {
  DecentBenchLogger({
    WorkspaceDatabaseGateway Function()? gatewayFactory,
    String? logDatabasePath,
  }) : _gatewayFactory = gatewayFactory ?? DecentDbBridge.new,
       _logDatabasePath =
           logDatabasePath ?? AppSupportPaths.resolveLogDatabasePath();

  final WorkspaceDatabaseGateway Function() _gatewayFactory;
  final String _logDatabasePath;

  WorkspaceDatabaseGateway? _gateway;
  Future<void>? _initialization;
  Future<void> _writeChain = Future<void>.value();
  LogVerbosity _minimumLevel = LogVerbosity.warning;
  bool _loggingDisabled = false;
  bool _reportedLoggingFailure = false;

  @override
  String get logDatabasePath => _logDatabasePath;

  @override
  Future<void> initialize({LogVerbosity? minimumLevel}) async {
    if (minimumLevel != null) {
      _minimumLevel = minimumLevel;
    }
    if (_loggingDisabled) {
      return;
    }
    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }

    final initialization = _initializeSafely();
    _initialization = initialization;
    await initialization;
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

    final mergedDetails = _normalizeDetails(
      details,
      error: error,
      stackTrace: stackTrace,
    );
    final entry = _LogEntry(
      loggedAtUtc: DateTime.now().toUtc(),
      level: level,
      category: category,
      message: message,
      operation: operation,
      databasePath: databasePath,
      sql: sql,
      rowCount: rowCount,
      rowsAffected: rowsAffected,
      elapsedNanos: elapsedNanos,
      detailsJson: mergedDetails == null ? null : jsonEncode(mergedDetails),
    );
    if (level.value >= LogVerbosity.warning.value) {
      final operationSuffix = operation == null ? '' : ' [$operation]';
      debugPrint(
        '[${level.label.toUpperCase()}][$category$operationSuffix] $message',
      );
    }
    if (_loggingDisabled) {
      return;
    }
    _enqueueWrite(entry);
  }

  @override
  Future<void> dispose() async {
    await _writeChain.catchError((_) {});
    await _disposeGateway();
    _initialization = null;
    _writeChain = Future<void>.value();
  }

  Future<void> _initializeSafely() async {
    try {
      await _initializeInternal();
    } catch (error, stackTrace) {
      if (await _recoverFromInitializationFailure(error, stackTrace)) {
        return;
      }
      await _disableLogging(
        'Failed to initialize application log database.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeInternal() async {
    final file = File(_logDatabasePath);
    await file.parent.create(recursive: true);
    final gateway = _gatewayFactory();
    try {
      await gateway.initialize();
      await gateway.openDatabase(_logDatabasePath);
      final schema = await gateway.loadSchema();
      final hasLogsTable = schema.tables.any(
        (table) => table.name == 'app_logs',
      );
      final hasLoggedAtIndex = schema.indexes.any(
        (index) => index.name == 'idx_app_logs_logged_at',
      );
      if (!hasLogsTable) {
        await gateway.runQuery(
          sql: '''
CREATE TABLE IF NOT EXISTS app_logs (
  id INTEGER PRIMARY KEY,
  logged_at_utc TEXT NOT NULL,
  level_value INTEGER NOT NULL,
  level_name TEXT NOT NULL,
  category TEXT NOT NULL,
  operation TEXT,
  message TEXT NOT NULL,
  database_path TEXT,
  sql_text TEXT,
  row_count INTEGER,
  rows_affected INTEGER,
  elapsed_nanos INTEGER,
  details_json TEXT
);
''',
          params: const <Object?>[],
          pageSize: 1,
        );
      }
      if (!hasLoggedAtIndex) {
        await gateway.runQuery(
          sql: '''
CREATE INDEX IF NOT EXISTS idx_app_logs_logged_at
ON app_logs(logged_at_utc DESC);
''',
          params: const <Object?>[],
          pageSize: 1,
        );
      }
      _gateway = gateway;
      await _persistEntryWithGateway(
        gateway,
        _LogEntry(
          loggedAtUtc: DateTime.now().toUtc(),
          level: LogVerbosity.information,
          category: 'logging',
          operation: 'initialize',
          message: 'Application logging initialized.',
          detailsJson: jsonEncode(<String, Object?>{
            'log_database_path': _logDatabasePath,
            'minimum_level': _minimumLevel.name,
          }),
        ),
      );
    } catch (_) {
      await gateway.dispose();
      rethrow;
    }
  }

  void _enqueueWrite(_LogEntry entry) {
    if (_loggingDisabled) {
      return;
    }
    _writeChain = _writeChain.then((_) => _writeEntry(entry)).catchError((
      error,
      stackTrace,
    ) async {
      await _disableLogging(
        'Failed to persist application log entry.',
        error: error,
        stackTrace: stackTrace is StackTrace ? stackTrace : null,
      );
    });
  }

  Future<void> _writeEntry(_LogEntry entry) async {
    if (_loggingDisabled) {
      return;
    }
    try {
      await initialize();
      if (_loggingDisabled) {
        return;
      }
      final gateway = _gateway;
      if (gateway == null) {
        return;
      }
      await _persistEntryWithGateway(gateway, entry);
    } catch (error, stackTrace) {
      await _disableLogging(
        'Failed to write application log entry.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _recoverFromInitializationFailure(
    Object error,
    StackTrace stackTrace,
  ) async {
    if (!_isRecoverableLogDatabaseFailure(error)) {
      return false;
    }

    await _disposeGateway();
    final deleted = await _deleteLogDatabaseFiles();
    if (!deleted) {
      return false;
    }

    _writeToStderrOnce(
      'Replaced an incompatible application log database at $_logDatabasePath.',
    );

    try {
      await _initializeInternal();
      return true;
    } catch (retryError, retryStackTrace) {
      await _disableLogging(
        'Failed to recreate the application log database after replacing a stale copy.',
        error: retryError,
        stackTrace: retryStackTrace,
      );
      return false;
    }
  }

  bool _isRecoverableLogDatabaseFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unsupported database format version') ||
        message.contains('database corruption') ||
        message.contains('not a database') ||
        message.contains('malformed');
  }

  Future<bool> _deleteLogDatabaseFiles() async {
    var deletedAny = false;
    for (final path in <String>[
      _logDatabasePath,
      '$_logDatabasePath-wal',
      '$_logDatabasePath-shm',
    ]) {
      final file = File(path);
      try {
        if (await file.exists()) {
          await file.delete();
          deletedAny = true;
        }
      } on FileSystemException {
        return false;
      }
    }
    return deletedAny;
  }

  Future<void> _disposeGateway() async {
    final gateway = _gateway;
    _gateway = null;
    if (gateway != null) {
      await gateway.dispose();
    }
  }

  Future<void> _disableLogging(
    String reason, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (_loggingDisabled) {
      return;
    }
    _loggingDisabled = true;
    _initialization = Future<void>.value();
    _writeChain = Future<void>.value();
    await _disposeGateway();

    final buffer = StringBuffer(reason)
      ..write(' Logging will continue in memory only for this session.')
      ..write(' Log database: $_logDatabasePath');
    if (error != null) {
      buffer.write(' Error: $error');
    }
    _writeToStderrOnce(buffer.toString(), stackTrace: stackTrace);
  }

  void _writeToStderrOnce(String message, {StackTrace? stackTrace}) {
    if (_reportedLoggingFailure) {
      return;
    }
    _reportedLoggingFailure = true;
    stderr.writeln(message);
    if (stackTrace != null) {
      stderr.writeln(stackTrace);
    }
  }

  Future<void> _persistEntryWithGateway(
    WorkspaceDatabaseGateway gateway,
    _LogEntry entry,
  ) async {
    await gateway.runQuery(
      sql: '''
INSERT INTO app_logs (
  logged_at_utc,
  level_value,
  level_name,
  category,
  operation,
  message,
  database_path,
  sql_text,
  row_count,
  rows_affected,
  elapsed_nanos,
  details_json
) VALUES (
  \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12
);
''',
      params: <Object?>[
        entry.loggedAtUtc.toIso8601String(),
        entry.level.value,
        entry.level.label,
        entry.category,
        entry.operation,
        entry.message,
        entry.databasePath,
        entry.sql,
        entry.rowCount,
        entry.rowsAffected,
        entry.elapsedNanos,
        entry.detailsJson,
      ],
      pageSize: 1,
    );
  }

  Map<String, Object?>? _normalizeDetails(
    Map<String, Object?>? details, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final normalized = <String, Object?>{};
    if (details != null) {
      for (final entry in details.entries) {
        normalized[entry.key] = _normalizeDetailValue(entry.value);
      }
    }
    if (error != null) {
      normalized['error'] = error.toString();
    }
    if (stackTrace != null) {
      normalized['stack_trace'] = stackTrace.toString();
    }
    return normalized.isEmpty ? null : normalized;
  }

  Object? _normalizeDetailValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map<Object?>((item) => _normalizeDetailValue(item)).toList();
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, item) => MapEntry(key.toString(), _normalizeDetailValue(item)),
      );
    }
    return value.toString();
  }
}

class _LogEntry {
  const _LogEntry({
    required this.loggedAtUtc,
    required this.level,
    required this.category,
    required this.message,
    this.operation,
    this.databasePath,
    this.sql,
    this.rowCount,
    this.rowsAffected,
    this.elapsedNanos,
    this.detailsJson,
  });

  final DateTime loggedAtUtc;
  final LogVerbosity level;
  final String category;
  final String message;
  final String? operation;
  final String? databasePath;
  final String? sql;
  final int? rowCount;
  final int? rowsAffected;
  final int? elapsedNanos;
  final String? detailsJson;
}
