import 'dart:io';

import 'package:decent_bench/app/logging/app_logger.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/decentdb_test_constants.dart';

void main() {
  group('ClefAppLogger', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('clef_logger_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates session log file on initialize', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);

      await logger.initialize(minimumLevel: LogVerbosity.debug);

      expect(logger.sessionLogFilePath, isNotEmpty);
      final file = File(logger.sessionLogFilePath);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Application session started.'));
      expect(content, contains('"@l":"Information"'));
      expect(content, contains('"category":"app"'));
    });

    test('writes log entries with structured fields', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.debug);

      logger.info(
        category: 'workspace',
        operation: 'open_database',
        message: 'Opened database successfully.',
        databasePath: '/tmp/test.ddb',
        rowCount: 100,
        details: <String, Object?>{
          'engine_version': expectedDecentDbVersion,
          'schema_tables': 5,
        },
      );

      final content = await File(logger.sessionLogFilePath).readAsString();
      expect(content, contains('"category":"workspace"'));
      expect(content, contains('"operation":"open_database"'));
      expect(content, contains('"@mt":"Opened database successfully."'));
      expect(content, contains('"databasePath":"/tmp/test.ddb"'));
      expect(content, contains('"rowCount":100'));
      expect(content, contains('"engine_version":"$expectedDecentDbVersion"'));
      expect(content, contains('"schema_tables":5'));
      expect(content, contains('"@l":"Information"'));
    });

    test('respects verbosity threshold', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.warning);

      logger.debug(
        category: 'test',
        message: 'should be filtered',
      );
      logger.info(
        category: 'test',
        message: 'also filtered',
      );
      logger.warning(
        category: 'test',
        message: 'should appear',
      );

      final content = await File(logger.sessionLogFilePath).readAsString();
      expect(content, isNot(contains('should be filtered')));
      expect(content, isNot(contains('also filtered')));
      expect(content, contains('should appear'));
    });

    test('records error and stackTrace', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.debug);

      try {
        throw StateError('test error');
      } catch (e, st) {
        logger.error(
          category: 'query',
          message: 'Query execution failed.',
          error: e,
          stackTrace: st,
        );
      }

      final content = await File(logger.sessionLogFilePath).readAsString();
      expect(content, contains('"error":"Bad state: test error"'));
      expect(content, contains('"errorType":"StateError"'));
      expect(content, contains('"stackTrace"'));
      expect(content, contains('"@l":"Error"'));
    });

    test('writes session end on dispose', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.debug);

      await logger.dispose();

      final content = await File(logger.sessionLogFilePath).readAsString();
      expect(content, contains('Application session ended.'));
    });

    test('updates minimum level', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.debug);

      logger.info(
        category: 'test',
        message: 'initial',
      );

      logger.updateMinimumLevel(LogVerbosity.error);
      logger.info(
        category: 'test',
        message: 'after change',
      );

      logger.error(
        category: 'test',
        message: 'error after change',
      );

      final content = await File(logger.sessionLogFilePath).readAsString();
      expect(content, contains('"@mt":"initial"'));
      expect(
        content.split('\n').where(
          (line) => line.contains('"@mt":"after change"'),
        ),
        isEmpty,
      );
      expect(content, contains('"@mt":"error after change"'));
    });

    test('logDirectoryPath returns configured directory', () {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      expect(logger.logDirectoryPath, tempDir.path);
    });

    test('appends to same file across multiple initializations', () async {
      final logger = ClefAppLogger(logDirectory: tempDir.path);
      await logger.initialize(minimumLevel: LogVerbosity.debug);
      final logPath = logger.sessionLogFilePath;

      logger.info(
        category: 'test',
        message: 'first entry',
      );

      logger.updateMinimumLevel(LogVerbosity.debug);
      await logger.initialize(minimumLevel: LogVerbosity.debug);
      expect(logger.sessionLogFilePath, logPath);

      logger.info(
        category: 'test',
        message: 'second entry',
      );

      final content = await File(logPath).readAsString();
      expect(content, contains('first entry'));
      expect(content, contains('second entry'));
    });
  });
}
