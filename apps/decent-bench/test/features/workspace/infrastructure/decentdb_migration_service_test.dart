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
}
