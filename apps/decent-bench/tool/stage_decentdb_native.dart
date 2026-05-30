import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_native_release_asset.dart';
import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  late final Map<String, String?> options;
  try {
    options = _parseArgs(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _printUsage(stderr);
    exitCode = 64;
    return;
  }
  final bundlePath = options['bundle']?.trim() ?? '';
  final sourcePath = options['source']?.trim();
  final migrationToolSourcePath = options['migration-tool-source']?.trim();
  final cliSourcePath = options['cli-source']?.trim();
  final verifyOnly = options.containsKey('verify-only');

  if (bundlePath.isEmpty) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  final resolver = NativeLibraryResolver();
  final destinationPath = p.join(
    bundlePath,
    resolver.bundleRelativeInstallPath,
  );
  final destinationFile = File(destinationPath);
  final migrationToolDestinationPath = p.join(
    bundlePath,
    resolver.migrationToolBundleRelativeInstallPath,
  );
  final migrationToolDestinationFile = File(migrationToolDestinationPath);
  final cliDestinationPath = p.join(
    bundlePath,
    resolver.cliToolBundleRelativeInstallPath,
  );
  final cliDestinationFile = File(cliDestinationPath);

  if (verifyOnly) {
    if (!destinationFile.existsSync()) {
      stderr.writeln(
        'Expected bundled DecentDB native library at $destinationPath, but no file was found.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Verified bundled DecentDB native library: $destinationPath',
    );
    if (!migrationToolDestinationFile.existsSync()) {
      stderr.writeln(
        'Expected bundled DecentDB migration tool at $migrationToolDestinationPath, but no file was found.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'Verified bundled DecentDB migration tool: $migrationToolDestinationPath',
    );
    if (!cliDestinationFile.existsSync()) {
      stderr.writeln(
        'Expected bundled DecentDB CLI at $cliDestinationPath, but no file was found.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('Verified bundled DecentDB CLI: $cliDestinationPath');
    return;
  }

  DecentDbNativeReleaseAsset? releaseAsset;
  DecentDbNativeReleaseAsset resolveReleaseAsset() {
    return releaseAsset ??= DecentDbNativeReleaseAsset.locate(
      startPath: Directory.current.path,
    );
  }

  final sourceFile = File(
    sourcePath?.isNotEmpty == true
        ? sourcePath!
        : _localDecentDbPathDependencyArtifact(resolver.libraryFileName) ??
              await resolveReleaseAsset().ensureAvailable(),
  );
  if (!sourceFile.existsSync()) {
    stderr.writeln(
      'Resolved DecentDB native library source file does not exist: ${sourceFile.path}',
    );
    exitCode = 1;
    return;
  }

  await destinationFile.parent.create(recursive: true);
  await sourceFile.copy(destinationFile.path);
  stdout.writeln('Staged ${sourceFile.path} -> ${destinationFile.path}');

  final migrationToolSourceFile = File(
    migrationToolSourcePath?.isNotEmpty == true
        ? migrationToolSourcePath!
        : _localDecentDbPathDependencyArtifact(
                resolver.migrationToolFileName,
              ) ??
              await resolveReleaseAsset().ensureMigrationToolAvailable(),
  );
  if (!migrationToolSourceFile.existsSync()) {
    stderr.writeln(
      'Resolved DecentDB migration tool source file does not exist: ${migrationToolSourceFile.path}',
    );
    exitCode = 1;
    return;
  }

  await migrationToolDestinationFile.parent.create(recursive: true);
  await migrationToolSourceFile.copy(migrationToolDestinationFile.path);
  if (!Platform.isWindows) {
    await Process.run('chmod', <String>[
      '755',
      migrationToolDestinationFile.path,
    ]);
  }
  stdout.writeln(
    'Staged ${migrationToolSourceFile.path} -> ${migrationToolDestinationFile.path}',
  );

  final cliSourceFile = File(
    cliSourcePath?.isNotEmpty == true
        ? cliSourcePath!
        : _localDecentDbPathDependencyArtifact(resolver.cliToolFileName) ??
              await resolveReleaseAsset().ensureCliToolAvailable(),
  );
  if (!cliSourceFile.existsSync()) {
    stderr.writeln(
      'Resolved DecentDB CLI source file does not exist: ${cliSourceFile.path}',
    );
    exitCode = 1;
    return;
  }

  await cliDestinationFile.parent.create(recursive: true);
  await cliSourceFile.copy(cliDestinationFile.path);
  if (!Platform.isWindows) {
    await Process.run('chmod', <String>['755', cliDestinationFile.path]);
  }
  stdout.writeln('Staged ${cliSourceFile.path} -> ${cliDestinationFile.path}');
}

String? _localDecentDbPathDependencyArtifact(String fileName) {
  final projectDirectory = _findProjectDirectory(Directory.current.path);
  if (projectDirectory == null) {
    return null;
  }
  final lockFile = File(p.join(projectDirectory, 'pubspec.lock'));
  if (!lockFile.existsSync()) {
    return null;
  }
  final dependencyPath = _parseDecentDbPathDependency(
    lockFile.readAsStringSync(),
  );
  if (dependencyPath == null || dependencyPath.trim().isEmpty) {
    return null;
  }

  var dependencyDirectory = Directory(
    p.isAbsolute(dependencyPath)
        ? dependencyPath
        : p.join(projectDirectory, dependencyPath),
  ).absolute;

  for (var depth = 0; depth < 8; depth++) {
    for (final candidate in <String>[
      p.join(dependencyDirectory.path, 'target', 'release', fileName),
      p.join(dependencyDirectory.path, 'target', 'debug', fileName),
      p.join(dependencyDirectory.path, 'build', fileName),
      p.join(dependencyDirectory.path, 'native', fileName),
      p.join(dependencyDirectory.path, 'native', 'bin', fileName),
      p.join(dependencyDirectory.path, 'native', 'lib', fileName),
    ]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    final parent = dependencyDirectory.parent;
    if (parent.path == dependencyDirectory.path) {
      break;
    }
    dependencyDirectory = parent;
  }
  return null;
}

String? _findProjectDirectory(String startPath) {
  var current = Directory(startPath).absolute;
  while (true) {
    if (File(p.join(current.path, 'pubspec.lock')).existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}

String? _parseDecentDbPathDependency(String contents) {
  var insideDecentDb = false;
  var insideDescription = false;
  for (final line in contents.split('\n')) {
    if (line.startsWith('  decentdb:')) {
      insideDecentDb = true;
      insideDescription = false;
      continue;
    }
    if (insideDecentDb && line.startsWith('  ') && !line.startsWith('    ')) {
      break;
    }
    if (!insideDecentDb) {
      continue;
    }
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('description:')) {
      insideDescription = true;
      continue;
    }
    if (insideDescription && trimmed.startsWith('path: ')) {
      return _unquote(trimmed.substring(6).trim());
    }
  }
  return null;
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

Map<String, String?> _parseArgs(List<String> args) {
  final options = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final argument = args[i];
    switch (argument) {
      case '--bundle':
        if (i + 1 >= args.length) {
          throw const FormatException('--bundle requires a value.');
        }
        options['bundle'] = args[++i];
        break;
      case '--source':
        if (i + 1 >= args.length) {
          throw const FormatException('--source requires a value.');
        }
        options['source'] = args[++i];
        break;
      case '--migration-tool-source':
        if (i + 1 >= args.length) {
          throw const FormatException(
            '--migration-tool-source requires a value.',
          );
        }
        options['migration-tool-source'] = args[++i];
        break;
      case '--cli-source':
        if (i + 1 >= args.length) {
          throw const FormatException('--cli-source requires a value.');
        }
        options['cli-source'] = args[++i];
        break;
      case '--verify-only':
        options['verify-only'] = 'true';
        break;
      case '--help':
      case '-h':
        _printUsage(stdout);
        exit(0);
      default:
        throw FormatException('Unknown argument: $argument');
    }
  }
  return options;
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/stage_decentdb_native.dart --bundle <bundle-path> [--source <native-lib-path>] [--migration-tool-source <decentdb-migrate-path>] [--cli-source <decentdb-path>] [--verify-only]',
  );
}
