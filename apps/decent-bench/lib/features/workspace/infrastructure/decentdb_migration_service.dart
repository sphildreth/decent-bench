import 'dart:io';

import 'package:path/path.dart' as p;

import 'decentdb_native_release_asset.dart';

typedef DecentDbMigrationToolPathResolver = Future<String> Function();
typedef DecentDbMigrationProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class DecentDbMigrationResult {
  const DecentDbMigrationResult({
    required this.sourcePath,
    required this.destinationPath,
    required this.toolPath,
    required this.stdoutText,
    required this.stderrText,
    required this.elapsed,
  });

  final String sourcePath;
  final String destinationPath;
  final String toolPath;
  final String stdoutText;
  final String stderrText;
  final Duration elapsed;
}

class DecentDbMigrationFailure implements Exception {
  const DecentDbMigrationFailure({
    required this.message,
    this.exitCode,
    this.stdoutText = '',
    this.stderrText = '',
    this.toolPath,
  });

  final String message;
  final int? exitCode;
  final String stdoutText;
  final String stderrText;
  final String? toolPath;

  String get detailText {
    final parts = <String>[
      message,
      if (exitCode != null) 'Exit code: $exitCode',
      if (toolPath != null && toolPath!.isNotEmpty) 'Tool: $toolPath',
      if (stdoutText.trim().isNotEmpty) 'Output:\n${stdoutText.trim()}',
      if (stderrText.trim().isNotEmpty) 'Error output:\n${stderrText.trim()}',
    ];
    return parts.join('\n\n');
  }

  @override
  String toString() => detailText;
}

class DecentDbMigrationService {
  DecentDbMigrationService({
    DecentDbMigrationToolPathResolver? toolPathResolver,
    DecentDbMigrationProcessRunner? processRunner,
    Map<String, String>? environment,
  }) : _toolPathResolver = toolPathResolver,
       _processRunner = processRunner ?? _defaultProcessRunner,
       _environment = environment ?? Platform.environment;

  static const String toolBaseName = 'decentdb-migrate';

  final DecentDbMigrationToolPathResolver? _toolPathResolver;
  final DecentDbMigrationProcessRunner _processRunner;
  final Map<String, String> _environment;

  static bool isUnsupportedFormatVersionMessage(String? message) {
    final normalized = message?.toLowerCase() ?? '';
    return normalized.contains('unsupported database format version') ||
        normalized.contains('unsupportedformatversion') ||
        normalized.contains('legacy format version') ||
        normalized.contains('database is in legacy format version');
  }

  static String migrationToolFileName({bool isWindows = false}) =>
      isWindows ? '$toolBaseName.exe' : toolBaseName;

  Future<String> suggestDestinationPath(String sourcePath) async {
    final directory = p.dirname(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath).trim().isEmpty
        ? 'database'
        : p.basenameWithoutExtension(sourcePath).trim();
    final first = p.join(directory, '${baseName}_migrated.ddb');
    if (!await File(first).exists()) {
      return first;
    }
    for (var index = 2; index < 1000; index++) {
      final candidate = p.join(directory, '${baseName}_migrated_$index.ddb');
      if (!await File(candidate).exists()) {
        return candidate;
      }
    }
    return p.join(
      directory,
      '${baseName}_migrated_${DateTime.now().millisecondsSinceEpoch}.ddb',
    );
  }

  Future<DecentDbMigrationResult> migrate({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final normalizedSource = p.normalize(sourcePath.trim());
    final normalizedDestination = p.normalize(destinationPath.trim());
    if (normalizedSource.isEmpty) {
      throw const DecentDbMigrationFailure(
        message: 'Choose a legacy DecentDB source file to migrate.',
      );
    }
    if (normalizedDestination.isEmpty) {
      throw const DecentDbMigrationFailure(
        message: 'Choose a destination path for the migrated database.',
      );
    }
    if (p.equals(normalizedSource, normalizedDestination)) {
      throw const DecentDbMigrationFailure(
        message:
            'Migration writes to a new DecentDB file. Choose a destination different from the source file.',
      );
    }

    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'Legacy DecentDB source file does not exist: $normalizedSource',
      );
    }
    final destinationFile = File(normalizedDestination);
    if (await destinationFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'The migration destination already exists. Choose a new file so the original data is not overwritten: $normalizedDestination',
      );
    }

    await destinationFile.parent.create(recursive: true);
    final toolPath = await resolveToolPath();
    final stopwatch = Stopwatch()..start();
    final result = await _processRunner(toolPath, <String>[
      '--source',
      normalizedSource,
      '--dest',
      normalizedDestination,
    ]);
    stopwatch.stop();

    final stdoutText = _processText(result.stdout);
    final stderrText = _processText(result.stderr);
    if (result.exitCode != 0) {
      throw DecentDbMigrationFailure(
        message: 'DecentDB migration failed.',
        exitCode: result.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }
    if (!await destinationFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'DecentDB migration completed but did not create the expected destination file.',
        exitCode: result.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }

    return DecentDbMigrationResult(
      sourcePath: normalizedSource,
      destinationPath: normalizedDestination,
      toolPath: toolPath,
      stdoutText: stdoutText,
      stderrText: stderrText,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<String> resolveToolPath() async {
    final injectedResolver = _toolPathResolver;
    if (injectedResolver != null) {
      return injectedResolver();
    }

    for (final candidate in _configuredToolCandidates()) {
      if (candidate.isNotEmpty && File(candidate).existsSync()) {
        return candidate;
      }
    }

    try {
      return await DecentDbNativeReleaseAsset.locate()
          .ensureMigrationToolAvailable();
    } catch (error) {
      final pathCandidate = _findExecutableOnPath(
        migrationToolFileName(isWindows: Platform.isWindows),
      );
      if (pathCandidate != null) {
        return pathCandidate;
      }

      throw DecentDbMigrationFailure(
        message:
            'Unable to resolve the official decentdb-migrate tool. Install it from the DecentDB release bundle, place it on PATH, or set DECENTDB_MIGRATE_PATH.',
        stderrText: error.toString(),
      );
    }
  }

  Iterable<String> _configuredToolCandidates() sync* {
    yield _environment['DECENTDB_MIGRATE_PATH'] ?? '';
    yield _environment['DECENTDB_MIGRATE'] ?? '';

    final toolFile = migrationToolFileName(isWindows: Platform.isWindows);
    final executableDir = p.dirname(Platform.resolvedExecutable);
    yield p.join(executableDir, toolFile);
    yield p.join(executableDir, 'bin', toolFile);
    yield p.join(executableDir, 'libexec', toolFile);

    yield* DecentDbNativeReleaseAsset.cachedMigrationToolCandidates(
      searchRoots: <String>[Directory.current.path, executableDir],
      platform: _currentNativeAssetPlatform(),
    );
  }

  String? _findExecutableOnPath(String executableName) {
    final pathValue = _environment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return null;
    }
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) {
        continue;
      }
      final candidate = p.join(directory, executableName);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }

  static String _processText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is List<int>) {
      return String.fromCharCodes(value);
    }
    return value.toString();
  }

  static DecentDbNativeAssetPlatform _currentNativeAssetPlatform() {
    if (Platform.isLinux) {
      return DecentDbNativeAssetPlatform.linux;
    }
    if (Platform.isMacOS) {
      return DecentDbNativeAssetPlatform.macos;
    }
    if (Platform.isWindows) {
      return DecentDbNativeAssetPlatform.windows;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
