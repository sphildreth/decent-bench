import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('detects unsupported legacy format open errors', () {
    expect(
      DecentDbMigrationService.isUnsupportedFormatVersionMessage(
        'Unsupported database format version: 3',
      ),
      isTrue,
    );
    expect(
      DecentDbMigrationService.isUnsupportedFormatVersionMessage(
        'UnsupportedFormatVersion',
      ),
      isTrue,
    );
    expect(
      DecentDbMigrationService.isUnsupportedFormatVersionMessage(
        'syntax error near SELECT',
      ),
      isFalse,
    );
  });

  test('detects DDB_ERR_TIMEOUT engine messages', () {
    expect(
      DecentDbMigrationService.isCoordinationTimeoutMessage(
        'DecentDBException: DDB_ERR_TIMEOUT (10)',
      ),
      isTrue,
    );
    expect(
      DecentDbMigrationService.isCoordinationTimeoutMessage(
        'ErrTimeout waiting for writer lock',
      ),
      isTrue,
    );
    expect(
      DecentDbMigrationService.isCoordinationTimeoutMessage(
        'process writer lock wait timed out',
      ),
      isTrue,
    );
    expect(
      DecentDbMigrationService.isCoordinationTimeoutMessage(
        'database file is corrupt',
      ),
      isFalse,
    );
  });

  test('explainCoordinationTimeout returns null for non-matching messages',
      () {
    expect(
      DecentDbMigrationService.explainCoordinationTimeout(
        'database file is corrupt',
        databasePath: '/tmp/foo.ddb',
      ),
      isNull,
    );
  });

  test('explainCoordinationTimeout names the .coord sidecar and the config '
      'knob to raise', () {
    final text = DecentDbMigrationService.explainCoordinationTimeout(
      'DDB_ERR_TIMEOUT',
      databasePath: '/mnt/incoming/foo.ddb',
    );
    expect(text, isNotNull);
    expect(text, contains('process writer lock'));
    expect(text, contains('/mnt/incoming/foo.ddb.coord'));
    expect(text, contains('process_coordination_timeout_ms'));
  });

  test('suggests a unique migrated destination beside the source', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'decentdb-migration-service-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final sourcePath = p.join(tempDir.path, 'legacy.ddb');
    await File(sourcePath).writeAsString('legacy');
    await File(
      p.join(tempDir.path, 'legacy_migrated.ddb'),
    ).writeAsString('existing');

    final service = DecentDbMigrationService(
      toolPathResolver: () async => '/tmp/decentdb-migrate',
    );

    expect(
      await service.suggestDestinationPath(sourcePath),
      p.join(tempDir.path, 'legacy_migrated_2.ddb'),
    );
  });

  test('runs decentdb-migrate with source and destination arguments', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'decentdb-migration-service-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final sourcePath = p.join(tempDir.path, 'legacy.ddb');
    final destinationPath = p.join(tempDir.path, 'legacy_migrated.ddb');
    await File(sourcePath).writeAsString('legacy');
    String? executable;
    List<String>? arguments;

    final service = DecentDbMigrationService(
      toolPathResolver: () async => '/tmp/decentdb-migrate',
      processRunner: (toolPath, toolArguments) async {
        executable = toolPath;
        arguments = toolArguments;
        await File(destinationPath).writeAsString('migrated');
        return ProcessResult(12, 0, 'Migration complete', '');
      },
    );

    final result = await service.migrate(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
    );

    expect(executable, '/tmp/decentdb-migrate');
    expect(arguments, <String>[
      '--source',
      sourcePath,
      '--dest',
      destinationPath,
    ]);
    expect(result.destinationPath, destinationPath);
    expect(result.stdoutText, contains('Migration complete'));
  });

  test('rejects in-place and overwrite migration destinations', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'decentdb-migration-service-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final sourcePath = p.join(tempDir.path, 'legacy.ddb');
    final destinationPath = p.join(tempDir.path, 'legacy_migrated.ddb');
    await File(sourcePath).writeAsString('legacy');
    await File(destinationPath).writeAsString('existing');
    final service = DecentDbMigrationService(
      toolPathResolver: () async => '/tmp/decentdb-migrate',
    );

    await expectLater(
      service.migrate(sourcePath: sourcePath, destinationPath: sourcePath),
      throwsA(isA<DecentDbMigrationFailure>()),
    );
    await expectLater(
      service.migrate(sourcePath: sourcePath, destinationPath: destinationPath),
      throwsA(isA<DecentDbMigrationFailure>()),
    );
  });

  test('surfaces migration process failure details', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'decentdb-migration-service-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final sourcePath = p.join(tempDir.path, 'legacy.ddb');
    final destinationPath = p.join(tempDir.path, 'legacy_migrated.ddb');
    await File(sourcePath).writeAsString('legacy');
    final service = DecentDbMigrationService(
      toolPathResolver: () async => '/tmp/decentdb-migrate',
      processRunner: (_, _) async {
        return ProcessResult(12, 2, 'started', 'unsupported legacy format');
      },
    );

    await expectLater(
      service.migrate(sourcePath: sourcePath, destinationPath: destinationPath),
      throwsA(
        isA<DecentDbMigrationFailure>()
            .having((error) => error.exitCode, 'exitCode', 2)
            .having(
              (error) => error.stderrText,
              'stderrText',
              contains('unsupported legacy format'),
            ),
      ),
    );
  });

  group('migrateInPlace', () {
    test('moves original aside, swaps migrated temp into place, and backs up '
        'the source WAL sidecar', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'decentdb-migration-service-in-place-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourcePath = p.join(tempDir.path, 'legacy.ddb');
      final walPath = '$sourcePath.wal';
      final sourceBytes = 'legacy-database-bytes';
      await File(sourcePath).writeAsString(sourceBytes);
      await File(walPath).writeAsString('legacy-wal-bytes');

      final service = DecentDbMigrationService(
        toolPathResolver: () async => '/tmp/decentdb-migrate',
        processRunner: (toolPath, args) async {
          final destIndex = args.indexOf('--dest');
          final tempDestination = args[destIndex + 1];
          await File(tempDestination).writeAsString('migrated-database-bytes');
          return ProcessResult(12, 0, 'Migration complete', '');
        },
      );

      final result = await service.migrateInPlace(sourcePath: sourcePath);

      expect(result.originalPath, sourcePath);
      expect(result.finalPath, sourcePath);
      expect(result.backupPath, '$sourcePath.v13.bak');
      expect(result.carryForwardSidecars, <String>['$sourcePath.wal.v13.bak']);
      expect(await File(result.backupPath).readAsString(), sourceBytes);
      expect(await File('$sourcePath.wal.v13.bak').readAsString(),
          'legacy-wal-bytes');
      expect(
        (await File(sourcePath).readAsString()),
        'migrated-database-bytes',
      );
      expect(await File(walPath).exists(), isFalse,
          reason: 'rebuildable sidecar should be gone, engine will recreate');
    });

    test('cleans up the temp destination when the tool returns zero but '
        'produces no output file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'decentdb-migration-service-in-place-no-output-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourcePath = p.join(tempDir.path, 'legacy.ddb');
      await File(sourcePath).writeAsString('legacy');

      final service = DecentDbMigrationService(
        toolPathResolver: () async => '/tmp/decentdb-migrate',
        processRunner: (_, _) async {
          return ProcessResult(12, 0, '', '');
        },
      );

      await expectLater(
        service.migrateInPlace(sourcePath: sourcePath),
        throwsA(isA<DecentDbMigrationFailure>()),
      );
      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(sourcePath).readAsString(), 'legacy');
    });

    test('propagates migration process failure without modifying the original',
        () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'decentdb-migration-service-in-place-tool-fail-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourcePath = p.join(tempDir.path, 'legacy.ddb');
      await File(sourcePath).writeAsString('legacy');

      final service = DecentDbMigrationService(
        toolPathResolver: () async => '/tmp/decentdb-migrate',
        processRunner: (_, _) async {
          return ProcessResult(12, 7, '', 'tool missing');
        },
      );

      await expectLater(
        service.migrateInPlace(sourcePath: sourcePath),
        throwsA(isA<DecentDbMigrationFailure>()),
      );
      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(sourcePath).readAsString(), 'legacy');
      expect(await File('$sourcePath.v13.bak').exists(), isFalse);
    });

    test('rejects when a backup already exists at the expected location',
        () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'decentdb-migration-service-in-place-backup-exists-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourcePath = p.join(tempDir.path, 'legacy.ddb');
      await File(sourcePath).writeAsString('legacy');
      await File('$sourcePath.v13.bak').writeAsString('existing');

      final service = DecentDbMigrationService(
        toolPathResolver: () async => '/tmp/decentdb-migrate',
      );
      await expectLater(
        service.migrateInPlace(sourcePath: sourcePath),
        throwsA(isA<DecentDbMigrationFailure>()),
      );
    });
  });
}
